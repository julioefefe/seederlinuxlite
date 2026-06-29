<?php
/**
 * Configuração de conexão com o banco de dados PostgreSQL
 * SeederLinux Lite
 */

$host = 'localhost';
$port = '5432';
$dbname = 'seederlinux';
$user = 'postgres';
$password = 'sua_senha_aqui'; // Ajustar conforme o ambiente local

try {
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname";
    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException $e) {
    // Em produção, não exibir detalhes do erro
    header('Content-Type: application/json', true, 500);
    echo json_encode(['error' => 'Erro de conexão com o banco de dados: ' . $e->getMessage()]);
    exit;
}

/**
 * Helper para enviar respostas JSON
 */
function sendJson($data, $status = 200) {
    header('Content-Type: application/json');
    http_response_code($status);
    echo json_encode($data);
    exit;
}
