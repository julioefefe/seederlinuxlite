-- Migração Autenticação - SeederLinux Lite

-- 1. Criar tabela users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    organization_id INT REFERENCES organizations(id) ON DELETE SET NULL, -- NULL para admin_gap
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('admin_gap', 'operador_om', 'auditor')),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Inserir usuário admin padrão (Senha: Admin@123)
-- Hash gerado via password_hash('Admin@123', PASSWORD_BCRYPT)
INSERT INTO users (name, email, password_hash, role, active)
VALUES ('Administrador GAP', 'admin@sistema.local', '$2y$10$7R0Wz/O2H8pX5.5R7X5X.O6X.X.X.X.X.X.X.X.X.X.X.X.X.X.', 'admin_gap', TRUE)
ON CONFLICT (email) DO NOTHING;

-- Nota: O hash acima é ilustrativo, o script de instalação deve gerar o hash real.
