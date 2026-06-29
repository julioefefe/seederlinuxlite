-- Migração Fase 2 - SeederLinux Lite

-- 1. Atualizar tabela variables
ALTER TABLE variables ADD COLUMN category VARCHAR(50);
ALTER TABLE variables ADD COLUMN required BOOLEAN DEFAULT FALSE;
ALTER TABLE variables ADD COLUMN default_value TEXT;

-- 2. Criar tabela deploy_profiles
CREATE TABLE IF NOT EXISTS deploy_profiles (
    id SERIAL PRIMARY KEY,
    organization_id INT REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    active BOOLEAN DEFAULT TRUE
);

-- 3. Criar tabela profile_scripts (Relacionamento N-N)
CREATE TABLE IF NOT EXISTS profile_scripts (
    profile_id INT REFERENCES deploy_profiles(id) ON DELETE CASCADE,
    script_id INT REFERENCES scripts(id) ON DELETE CASCADE,
    PRIMARY KEY (profile_id, script_id)
);

-- 4. Atualizar categorias das variáveis existentes (Exemplo para COMARA)
UPDATE variables SET category = 'dominio', required = TRUE WHERE name IN ('DOMINIO', 'DOMINIO_NETBIOS', 'DC_IP', 'DNS_PRIMARIO');
UPDATE variables SET category = 'navegador' WHERE name IN ('HOMEPAGE', 'PROXY_URL');
UPDATE variables SET category = 'inventario' WHERE name = 'OCS_SERVER';
UPDATE variables SET category = 'impressoras' WHERE name = 'PRINT_SERVER';
UPDATE variables SET category = 'seguranca' WHERE name = 'OFFLINE_AUTH_DAYS';

-- 5. Inserir scripts core placeholder (usuário irá subir os reais)
INSERT INTO scripts (name, content, is_core) VALUES 
('core_domain.sh', '# Script real de ingresso no domínio será inserido aqui', TRUE),
('core_branding.sh', '# Script real de personalização será inserido aqui', TRUE),
('core_printers.sh', '# Script real de impressoras será inserido aqui', TRUE),
('core_legacy.sh', '# Script real de sistemas legados será inserido aqui', TRUE),
('core_logon.sh', '# Script real de logon será inserido aqui', TRUE),
('core_logoff.sh', '# Script real de logoff será inserido aqui', TRUE),
('core_kixtart.sh', '# Script real de kixtart será inserido aqui', TRUE),
('core_kixtop.sh', '# Script real de kixtop será inserido aqui', TRUE),
('core_troca_senha.sh', '# Script real de troca de senha será inserido aqui', TRUE)
ON CONFLICT DO NOTHING;
