<?php
/**
 * Biblioteca de Processamento de Templates
 * SeederLinux Lite
 */

/**
 * Substitui placeholders no formato {{NOME_VARIAVEL}} pelo valor correspondente
 * 
 * @param string $content O conteúdo do script com placeholders
 * @param array $variables Array associativo [nome => valor]
 * @return string Conteúdo processado
 */
function replacePlaceholders($content, $variables) {
    if (empty($variables)) {
        return $content;
    }

    foreach ($variables as $name => $value) {
        $placeholder = '{{' . $name . '}}';
        $content = str_replace($placeholder, $value, $content);
    }

    // Opcional: Limpar placeholders não preenchidos ou avisar
    // preg_replace('/\{\{.*?\}\}/', '# VARIÁVEL NÃO DEFINIDA', $content);

    return $content;
}

/**
 * Funções utilitárias adicionais podem ser incluídas aqui
 * Ex: logs, sanitização, etc.
 */
