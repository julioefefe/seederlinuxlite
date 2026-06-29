<?php
require_once 'config.php';
require_once '../lib/auth.php';

$currentUser = requireAuth();

/**
 * Endpoint: /api/variables.php
 */

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Listar categorias oficiais
    if (isset($_GET['action']) && $_GET['action'] === 'categories') {
        $categories = [
            'dominio', 'arquivos', 'navegador', 'branding', 'inventario', 
            'remoto', 'impressoras', 'certificados', 'repositorios', 
            'seguranca', 'desktop', 'geral'
        ];
        sendJson($categories);
        exit;
    }

    // Listar variáveis de uma OM
    $orgId = isset($_GET['org']) ? (int)$_GET['org'] : null;
    if (!$orgId) {
        sendJson(['error' => 'ID da organização é obrigatório'], 400);
    }

    if (!checkPermission($currentUser, null, $orgId)) {
        sendJson(['error' => 'Acesso negado'], 403);
    }

    $stmt = $pdo->prepare("SELECT * FROM variables WHERE organization_id = ? ORDER BY category ASC, name ASC");
    $stmt->execute([$orgId]);
    sendJson($stmt->fetchAll());

} elseif ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['organization_id']) || !isset($input['name'])) {
        sendJson(['error' => 'Dados incompletos'], 400);
    }

    if (!checkPermission($currentUser, 'admin_gap', $input['organization_id'])) {
        sendJson(['error' => 'Acesso negado'], 403);
    }

    $stmt = $pdo->prepare("INSERT INTO variables (organization_id, name, value, category, required, default_value, type) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([
        $input['organization_id'],
        $input['name'],
        $input['value'] ?? null,
        $input['category'] ?? 'geral',
        isset($input['required']) ? (bool)$input['required'] : false,
        $input['default_value'] ?? null,
        $input['type'] ?? 'string'
    ]);

    sendJson(['message' => 'Variável criada com sucesso']);

} elseif ($method === 'PUT') {
    $input = json_decode(file_get_contents('php://input'), true);
    $id = (int)$_GET['id'];

    // Buscar a variável para checar permissão
    $stmtCheck = $pdo->prepare("SELECT organization_id FROM variables WHERE id = ?");
    $stmtCheck->execute([$id]);
    $var = $stmtCheck->fetch();

    if (!$var || !checkPermission($currentUser, null, $var['organization_id'])) {
        sendJson(['error' => 'Acesso negado ou variável não encontrada'], 403);
    }

    $stmt = $pdo->prepare("UPDATE variables SET value = ?, category = ?, required = ?, default_value = ?, type = ? WHERE id = ?");
    $stmt->execute([
        $input['value'] ?? null,
        $input['category'] ?? 'geral',
        isset($input['required']) ? (bool)$input['required'] : false,
        $input['default_value'] ?? null,
        $input['type'] ?? 'string',
        $id
    ]);

    sendJson(['message' => 'Variável atualizada']);
} else {
    sendJson(['error' => 'Método não permitido'], 405);
}
