<?php
require_once 'config.php';

/**
 * Endpoint: GET /api/scripts
 * Lista scripts disponíveis (Core + Específicos da OM)
 */

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $orgId = isset($_GET['org']) ? (int)$_GET['org'] : null;

    if ($orgId) {
        // Scripts Core OU scripts específicos daquela OM
        $stmt = $pdo->prepare("SELECT id, name, is_core, version FROM scripts WHERE is_core = TRUE OR organization_id = ? ORDER BY is_core DESC, name ASC");
        $stmt->execute([$orgId]);
    } else {
        // Apenas scripts Core se nenhuma OM for informada
        $stmt = $pdo->query("SELECT id, name, is_core, version FROM scripts WHERE is_core = TRUE ORDER BY name ASC");
    }

    $scripts = $stmt->fetchAll();
    sendJson($scripts);
} else {
    sendJson(['error' => 'Método não permitido'], 405);
}
