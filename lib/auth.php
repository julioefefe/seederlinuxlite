<?php
/**
 * Biblioteca de Autenticação e RBAC
 * SeederLinux Lite
 */

// Chave secreta para assinar o "token" (Em produção, use algo forte do .env)
define('JWT_SECRET', 'seederlinux_secret_key_2024');

/**
 * Gera um token simples (Base64 JSON assinado)
 */
function generateToken($payload) {
    $header = base64_encode(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
    $payload['exp'] = time() + (60 * 60 * 8); // 8 horas
    $payload_encoded = base64_encode(json_encode($payload));
    $signature = hash_hmac('sha256', "$header.$payload_encoded", JWT_SECRET);
    return "$header.$payload_encoded.$signature";
}

/**
 * Valida o token e retorna o payload
 */
function validateToken($token) {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;

    list($header, $payload, $signature) = $parts;
    $valid_signature = hash_hmac('sha256', "$header.$payload", JWT_SECRET);

    if ($signature !== $valid_signature) return null;

    $data = json_decode(base64_decode($payload), true);
    if ($data['exp'] < time()) return null;

    return $data;
}

/**
 * Middleware para proteger rotas
 */
function requireAuth() {
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if (!preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
        header('Content-Type: application/json', true, 401);
        echo json_encode(['error' => 'Não autorizado. Token ausente.']);
        exit;
    }

    $user = validateToken($matches[1]);
    if (!$user) {
        header('Content-Type: application/json', true, 401);
        echo json_encode(['error' => 'Sessão expirada ou token inválido.']);
        exit;
    }

    return $user;
}

/**
 * Verifica permissões RBAC
 */
function checkPermission($user, $requiredRole = null, $targetOrgId = null) {
    // Admin GAP pode tudo
    if ($user['role'] === 'admin_gap') return true;

    // Se exige uma role específica e o usuário não tem
    if ($requiredRole && $user['role'] !== $requiredRole) return false;

    // Se exige ser da mesma OM
    if ($targetOrgId !== null && (int)$user['organization_id'] !== (int)$targetOrgId) {
        return false;
    }

    return true;
}
