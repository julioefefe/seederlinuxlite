-- Refinamento de Variáveis - SeederLinux Lite

-- 1. Adicionar colunas se não existirem (usando IF NOT EXISTS via DO block para segurança)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='variables' AND COLUMN_NAME='category') THEN
        ALTER TABLE variables ADD COLUMN category VARCHAR(50) DEFAULT 'geral';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='variables' AND COLUMN_NAME='required') THEN
        ALTER TABLE variables ADD COLUMN required BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='variables' AND COLUMN_NAME='default_value') THEN
        ALTER TABLE variables ADD COLUMN default_value TEXT;
    END IF;
END $$;

-- 2. Atualizar categorias existentes para 'geral' se estiverem nulas
UPDATE variables SET category = 'geral' WHERE category IS NULL;
