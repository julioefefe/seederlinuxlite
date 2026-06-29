<?php
require_once 'config.php';
require_once '../lib/auth.php';

$currentUser = requireAuth();

/**
 * Endpoint: GET /api/organizations
 * Lista todas as organizações cadastradas
 */

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if (isset($_GET['id']) && isset($_GET['action']) && $_GET['action'] === 'variables') {
        $orgId = (int)$_GET['id'];
        if (!checkPermission($currentUser, null, $orgId)) {
            sendJson(['error' => 'Acesso negado a esta OM'], 403);
        }
        $stmt = $pdo->prepare("SELECT * FROM variables WHERE organization_id = ? ORDER BY category ASC, name ASC");
        $stmt->execute([$orgId]);
        $variables = $stmt->fetchAll();
        sendJson($variables);
    } else {
        if ($currentUser['role'] === 'admin_gap') {
            $stmt = $pdo->query("SELECT * FROM organizations WHERE active = TRUE ORDER BY acronym ASC");
        } else {
            $stmt = $pdo->prepare("SELECT * FROM organizations WHERE id = ? AND active = TRUE");
            $stmt->execute([$currentUser['organization_id']]);
        }
        $organizations = $stmt->fetchAll();
        sendJson($organizations);
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!isset($input['name']) || !isset($input['acronym'])) {
        sendJson(['error' => 'Nome e Sigla são obrigatórios'], 400);
    }

    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare("INSERT INTO organizations (name, acronym, domain) VALUES (?, ?, ?) RETURNING id");
        $stmt->execute([$input['name'], $input['acronym'], $input['domain'] ?? '']);
        $orgId = $stmt->fetchColumn();

        // 5. Variáveis Padrão por Categoria (Refinado)
        $defaults = [
            // categoria, nome, required, type
            ['dominio', 'DOMINIO', true, 'string'],
            ['dominio', 'DOMINIO_NETBIOS', true, 'string'],
            ['dominio', 'DC_IP', true, 'ip'],
            ['dominio', 'DNS_PRIMARIO', true, 'ip'],
            ['dominio', 'DNS_INTERNET', false, 'ip'],
            ['navegador', 'HOMEPAGE', false, 'url'],
            ['navegador', 'PROXY_HTTP', false, 'ip'],
            ['navegador', 'PROXY_PORTA', false, 'int'],
            ['branding', 'DISPLAY_NAME', false, 'string'],
            ['branding', 'WALLPAPER', false, 'url'],
            ['inventario', 'OCS_SERVER', false, 'url'],
            ['inventario', 'OCS_TAG', false, 'string'],
            ['impressoras', 'PRINT_SERVER', false, 'ip'],
            ['seguranca', 'GRUPO_ADMIN_AD', false, 'string'],
            ['seguranca', 'GRUPO_ADMIN_LINUX', false, 'string'],
            ['seguranca', 'GRUPO_DASTI', false, 'string'],
            ['seguranca', 'OFFLINE_AUTH_DAYS', false, 'int'],
            ['repositorios', 'BASE_URL', false, 'url']
        ];

        $stmtVar = $pdo->prepare("INSERT INTO variables (organization_id, category, name, required, type) VALUES (?, ?, ?, ?, ?)");
        foreach ($defaults as $v) {
            $stmtVar->execute([$orgId, $v[0], $v[1], $v[2], $v[3]]);
        }

        $pdo->commit();
        sendJson(['message' => 'OM criada com sucesso', 'id' => $orgId]);
    } catch (Exception $e) {
        $pdo->rollBack();
        sendJson(['error' => 'Erro ao criar OM: ' . $e->getMessage()], 500);
    }
} else {
    sendJson(['error' => 'Método não permitido'], 405);
}
