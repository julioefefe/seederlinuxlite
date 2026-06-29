<?php
require_once 'config.php';
require_once '../lib/auth.php';

$currentUser = requireAuth();
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // admin_gap vê todos, operador_om só sua OM
    if ($currentUser['role'] === 'admin_gap') {
        $orgId = isset($_GET['org']) ? (int)$_GET['org'] : null;
        if ($orgId) {
            $stmt = $pdo->prepare("SELECT id, name, email, role, organization_id, active FROM users WHERE organization_id = ?");
            $stmt->execute([$orgId]);
        } else {
            $stmt = $pdo->query("SELECT id, name, email, role, organization_id, active FROM users");
        }
    } else {
        $stmt = $pdo->prepare("SELECT id, name, email, role, organization_id, active FROM users WHERE organization_id = ?");
        $stmt->execute([$currentUser['organization_id']]);
    }
    sendJson($stmt->fetchAll());

} elseif ($method === 'POST') {
    if (!checkPermission($currentUser, 'admin_gap')) {
        sendJson(['error' => 'Acesso negado'], 403);
    }

    $input = json_decode(file_get_contents('php://input'), true);
    $hash = password_hash($input['password'], PASSWORD_BCRYPT);

    $stmt = $pdo->prepare("INSERT INTO users (name, email, password_hash, role, organization_id) VALUES (?, ?, ?, ?, ?)");
    $stmt->execute([$input['name'], $input['email'], $hash, $input['role'], $input['organization_id'] ?? null]);
    
    sendJson(['message' => 'Usuário criado']);

} elseif ($method === 'DELETE') {
    if (!checkPermission($currentUser, 'admin_gap')) {
        sendJson(['error' => 'Acesso negado'], 403);
    }
    
    $id = (int)$_GET['id'];
    $stmt = $pdo->prepare("UPDATE users SET active = FALSE WHERE id = ?");
    $stmt->execute([$id]);
    
    sendJson(['message' => 'Usuário desativado']);
}
