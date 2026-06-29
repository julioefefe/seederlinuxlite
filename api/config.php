<?php
/**
 * Configuração de conexão com o banco de dados PostgreSQL
 * SeederLinux Lite
 */

$host = 'localhost';
$port = '5432';
$dbname = 'seederlinuxtitle';
$user = 'seederlinuxtitle';
$password = 'seederlinuxtitle123';

try {
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname";
    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]);
} catch (PDOException $e) {
    header('Content-Type: application/json', true, 500);
    echo json_encode(['error' => 'Erro de conexão com o banco de dados']);
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
