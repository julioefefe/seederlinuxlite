<?php
// Configuração de conexão com PostgreSQL
function getDBConnection() {
    $host = 'localhost';
    $port = '5432';
    $dbname = 'seederlinux';
    $user = 'seederlinux';
    $password = 'seederlinux123';
    
    try {
        $dsn = "pgsql:host=$host;port=$port;dbname=$dbname";
        $pdo = new PDO(
            $dsn,
            $user,
            $password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false
            ]
        );
        return $pdo;
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Erro de conexão com o banco de dados: ' . $e->getMessage()
        ]);
        exit;
    }
}
