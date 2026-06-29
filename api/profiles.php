<?php
require_once 'config.php';

/**
 * Endpoint: /api/profiles.php
 */

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $orgId = isset($_GET['org']) ? (int)$_GET['org'] : null;
    
    if ($orgId) {
        $stmt = $pdo->prepare("SELECT * FROM deploy_profiles WHERE organization_id = ? AND active = TRUE");
        $stmt->execute([$orgId]);
        $profiles = $stmt->fetchAll();
        sendJson($profiles);
    } else {
        sendJson(['error' => 'ID da organização é obrigatório'], 400);
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['organization_id']) || !isset($input['name'])) {
        sendJson(['error' => 'Dados incompletos'], 400);
    }

    $stmt = $pdo->prepare("INSERT INTO deploy_profiles (organization_id, name, description) VALUES (?, ?, ?) RETURNING id");
    $stmt->execute([$input['organization_id'], $input['name'], $input['description'] ?? '']);
    $id = $stmt->fetchColumn();
    
    // Se enviou scripts para o perfil
    if (isset($input['script_ids']) && is_array($input['script_ids'])) {
        foreach ($input['script_ids'] as $scriptId) {
            $stmt = $pdo->prepare("INSERT INTO profile_scripts (profile_id, script_id) VALUES (?, ?)");
            $stmt->execute([$id, $scriptId]);
        }
    }

    sendJson(['message' => 'Perfil criado com sucesso', 'id' => $id]);
} else {
    sendJson(['error' => 'Método não permitido'], 405);
}
