<?php
require_once 'config.php';
require_once '../lib/template_engine.php';
require_once '../lib/auth.php';

$currentUser = requireAuth();

/**
 * Endpoint: POST /api/generate-bundle
 * Recebe {organization_id, script_ids} e gera o bundle final
 */

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Obter dados do corpo da requisição (JSON)
    $input = json_decode(file_get_contents('php://input'), true);

    if (!isset($input['organization_id']) || !isset($input['script_ids']) || !is_array($input['script_ids'])) {
        sendJson(['error' => 'Parâmetros inválidos. Requer organization_id e script_ids (array).'], 400);
    }

    $orgId = (int)$input['organization_id'];
    $scriptIds = $input['script_ids'] ?? [];
    $profileId = $input['profile_id'] ?? null;

    if (!checkPermission($currentUser, null, $orgId)) {
        sendJson(['error' => 'Acesso negado a esta OM'], 403);
    }

    try {
        // 1. Carregar variáveis da OM
        // Buscar valor real ou default_value se o valor for nulo
        $stmtVar = $pdo->prepare("SELECT name, COALESCE(value, default_value) as val FROM variables WHERE organization_id = ?");
        $stmtVar->execute([$orgId]);
        $variables = $stmtVar->fetchAll(PDO::FETCH_KEY_PAIR);

        // Verificar variáveis obrigatórias sem valor
        $stmtReq = $pdo->prepare("SELECT name FROM variables WHERE organization_id = ? AND required = TRUE AND value IS NULL AND default_value IS NULL");
        $stmtReq->execute([$orgId]);
        $missing = $stmtReq->fetchAll(PDO::FETCH_COLUMN);
        
        if (!empty($missing)) {
            sendJson(['error' => 'Variáveis obrigatórias não preenchidas: ' . implode(', ', $missing)], 400);
        }

        // 2. Se informou profile_id, carregar scripts do perfil
        if ($profileId) {
            $stmtProf = $pdo->prepare("SELECT script_id FROM profile_scripts WHERE profile_id = ?");
            $stmtProf->execute([$profileId]);
            $scriptIds = $stmtProf->fetchAll(PDO::FETCH_COLUMN);
        }

        if (empty($scriptIds)) {
            sendJson(['error' => 'Nenhum script selecionado ou perfil vazio.'], 400);
        }

        $placeholders = implode(',', array_fill(0, count($scriptIds), '?'));
        $stmtScripts = $pdo->prepare("SELECT content FROM scripts WHERE id IN ($placeholders) ORDER BY is_core DESC, id ASC");
        $stmtScripts->execute($scriptIds);
        $scriptsContent = $stmtScripts->fetchAll(PDO::FETCH_COLUMN);

        // 3. Concatenar scripts
        $fullContent = "#!/bin/bash\n";
        $fullContent .= "# SeederLinux Lite - Bundle gerado em " . date('Y-m-d H:i:s') . "\n";
        $fullContent .= "# Organização ID: $orgId\n\n";
        
        foreach ($scriptsContent as $content) {
            $fullContent .= "### INÍCIO DO MÓDULO ###\n";
            $fullContent .= $content . "\n";
            $fullContent .= "### FIM DO MÓDULO ###\n\n";
        }

        // 4. Substituir placeholders {{VARIAVEL}}
        $processedContent = replacePlaceholders($fullContent, $variables);

        // 5. Salvar bundle no banco
        $stmtSave = $pdo->prepare("INSERT INTO deploy_bundles (organization_id, content) VALUES (?, ?) RETURNING id");
        $stmtSave->execute([$orgId, $processedContent]);
        $bundleId = $stmtSave->fetchColumn();

        sendJson([
            'message' => 'Bundle gerado com sucesso',
            'bundle_id' => $bundleId,
            'download_url' => "api/bundle.php?id=$bundleId"
        ]);

    } catch (Exception $e) {
        sendJson(['error' => 'Erro ao gerar bundle: ' . $e->getMessage()], 500);
    }
} else {
    sendJson(['error' => 'Método não permitido'], 405);
}
