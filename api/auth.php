<?php
require_once 'config.php';
require_once '../lib/auth.php';

/**
 * Endpoints de Autenticação
 */

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

if ($method === 'POST' && $action === 'login') {
    $input = json_decode(file_get_contents('php://input'), true);
    $email = $input['email'] ?? '';
    $password = $input['password'] ?? '';

    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ? AND active = TRUE");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if ($user && password_verify($password, $user['password_hash'])) {
        $token = generateToken([
            'id' => $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'role' => $user['role'],
            'organization_id' => $user['organization_id']
        ]);

        sendJson([
            'token' => $token,
            'user' => [
                'name' => $user['name'],
                'role' => $user['role'],
                'organization_id' => $user['organization_id']
            ]
        ]);
    } else {
        sendJson(['error' => 'Credenciais inválidas'], 401);
    }
} elseif ($method === 'GET' && $action === 'me') {
    $user = requireAuth();
    sendJson($user);
} elseif ($method === 'POST' && $action === 'logout') {
    // No JWT puro stateless, o logout é feito no cliente removendo o token.
    // Opcionalmente pode-se ter uma blacklist no servidor.
    sendJson(['message' => 'Logout realizado']);
} else {
    sendJson(['error' => 'Ação não encontrada'], 404);
}
