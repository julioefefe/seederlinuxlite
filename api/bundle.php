<?php
require_once 'config.php';

/**
 * Endpoint: GET /api/bundle.php?id={id}
 * Faz o download do bundle gerado
 */

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if (!isset($_GET['id'])) {
        sendJson(['error' => 'ID do bundle não informado'], 400);
    }

    $bundleId = (int)$_GET['id'];

    $stmt = $pdo->prepare("SELECT b.content, o.acronym 
                           FROM deploy_bundles b 
                           JOIN organizations o ON b.organization_id = o.id 
                           WHERE b.id = ?");
    $stmt->execute([$bundleId]);
    $bundle = $stmt->fetch();

    if (!$bundle) {
        sendJson(['error' => 'Bundle não encontrado'], 404);
    }

    $filename = "seeder_bundle_" . strtolower($bundle['acronym']) . "_" . $bundleId . ".sh";

    header('Content-Type: text/x-shellscript');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    echo $bundle['content'];
    exit;
} else {
    sendJson(['error' => 'Método não permitido'], 405);
}
