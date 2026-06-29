#!/bin/bash
# Script de Instalação SeederLinux Lite

echo "--- Iniciando Instalação SeederLinux Lite ---"

# 1. Verificar dependências (Exemplo básico)
if ! command -v psql &> /dev/null; then
    echo "Erro: PostgreSQL não encontrado. Instale-o primeiro."
    exit 1
fi

# 2. Configurações de Banco (Ajuste conforme necessário)
DB_NAME="seederlinux"
DB_USER="postgres"

echo "Configurando banco de dados: $DB_NAME..."
# psql -U $DB_USER -c "CREATE DATABASE $DB_NAME;"
# psql -U $DB_USER -d $DB_NAME -f database/schema.sql
# psql -U $DB_USER -d $DB_NAME -f database/migration_fase2.sql
# psql -U $DB_USER -d $DB_NAME -f database/migration_auth.sql

# 3. Gerar usuário admin real com hash bcrypt
ADMIN_EMAIL="admin@sistema.local"
ADMIN_PASS="Admin@123"
# Usando PHP para gerar o hash do password_hash
HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")

echo "Atualizando senha do admin padrão..."
# psql -U $DB_USER -d $DB_NAME -c "UPDATE users SET password_hash = '$HASH' WHERE email = '$ADMIN_EMAIL';"

# 4. Ajustar permissões de diretórios
echo "Ajustando permissões de storage..."
chmod -R 775 storage
# chown -R www-data:www-data storage api painel

echo "--- Instalação Concluída ---"
echo "Acesse o painel em: http://localhost/seederlinux/painel/"
echo "Login: $ADMIN_EMAIL"
echo "Senha: $ADMIN_PASS"
