-- SeederLinux Lite - Database Schema
-- PostgreSQL 16+

-- Tabela de Organizações Militares (OMs)
CREATE TABLE IF NOT EXISTS organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    acronym VARCHAR(20) UNIQUE NOT NULL,
    domain VARCHAR(100),
    active BOOLEAN DEFAULT TRUE
);

-- Tabela de Variáveis por Organização
CREATE TABLE IF NOT EXISTS variables (
    id SERIAL PRIMARY KEY,
    organization_id INT REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    value TEXT,
    type VARCHAR(20) DEFAULT 'string', -- string, int, bool, json
    description TEXT,
    UNIQUE(organization_id, name)
);

-- Tabela de Scripts (Módulos)
CREATE TABLE IF NOT EXISTS scripts (
    id SERIAL PRIMARY KEY,
    organization_id INT REFERENCES organizations(id) ON DELETE CASCADE, -- NULL se for script core global
    name VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    version INT DEFAULT 1,
    is_core BOOLEAN DEFAULT FALSE
);

-- Tabela de Bundles Gerados (Histórico de Deploy)
CREATE TABLE IF NOT EXISTS deploy_bundles (
    id SERIAL PRIMARY KEY,
    organization_id INT REFERENCES organizations(id) ON DELETE CASCADE,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    content TEXT NOT NULL -- Script final processado
);

-- Dados de Exemplo: Organização COMARA
INSERT INTO organizations (name, acronym, domain, active) 
VALUES ('Comissão de Aeroportos da Região Amazônica', 'COMARA', 'comara.intraer', TRUE)
ON CONFLICT (acronym) DO NOTHING;

-- Variáveis de Exemplo para COMARA (Assumindo ID 1)
INSERT INTO variables (organization_id, name, value, type, description)
VALUES 
(1, 'DOMINIO', 'comara.intraer', 'string', 'Domínio AD da Organização'),
(1, 'DOMINIO_NETBIOS', 'COMARA', 'string', 'Nome NetBIOS do domínio'),
(1, 'DC_IP', '10.1.2.3', 'string', 'IP do Controlador de Domínio principal'),
(1, 'DNS_PRIMARIO', '10.1.2.3', 'string', 'Servidor DNS primário'),
(1, 'PROXY_URL', 'http://proxy.comara.intraer:3128', 'string', 'URL do proxy corporativo'),
(1, 'HOMEPAGE', 'https://www.comara.mil.br', 'string', 'Página inicial padrão do navegador'),
(1, 'OCS_SERVER', 'http://ocs.comara.intraer/ocsinventory', 'string', 'Servidor de inventário OCS'),
(1, 'PRINT_SERVER', '10.1.2.4', 'string', 'Servidor de impressão CUPS'),
(1, 'OFFLINE_AUTH_DAYS', '30', 'int', 'Dias permitidos para login offline (cache SSSD)')
ON CONFLICT (organization_id, name) DO NOTHING;

-- Script Core de Exemplo
INSERT INTO scripts (name, content, is_core)
VALUES 
('core_domain.sh', '#!/bin/bash\necho "Iniciando ingresso no domínio {{DOMINIO}}..."\necho "Configurando DNS para {{DNS_PRIMARIO}}..."\n# Comando real de ingresso aqui\necho "Ingresso concluído com sucesso."', TRUE),
('core_branding.sh', '#!/bin/bash\necho "Configurando papel de parede para a OM {{DOMINIO_NETBIOS}}..."\necho "Home page definida para {{HOMEPAGE}}"', TRUE)
ON CONFLICT DO NOTHING;
