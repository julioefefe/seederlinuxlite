#!/bin/bash
# =============================================================================
# instalar_seederlinux.sh - Instalação Completa do SeederLinux Lite
# =============================================================================
# Compatível com PostgreSQL 14+ (incluindo a versão 17)
# Uso: sudo ./instalar_seederlinux.sh
# =============================================================================

set -e

# Cores
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
VERMELHO='\033[0;31m'
SEM_COR='\033[0m'

echo -e "${AZUL}========================================${SEM_COR}"
echo -e "${AZUL}  SeederLinux Lite - Instalação         ${SEM_COR}"
echo -e "${AZUL}========================================${SEM_COR}"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}❌ Execute como root: sudo ./instalar_seederlinux.sh${SEM_COR}"
    exit 1
fi

# ============================================
# 1. DETECTAR SISTEMA
# ============================================
echo -e "${AZUL}═══ [1/10] Detectando sistema...${SEM_COR}"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSAO=$VERSION_ID
    CODENAME=$VERSION_CODENAME
else
    echo -e "${VERMELHO}❌ Sistema não suportado.${SEM_COR}"
    exit 1
fi

echo "   Distribuição: $NAME $VERSION"
echo "   Codename: $CODENAME"

# ============================================
# 2. DEFINIR CONFIGURAÇÕES
# ============================================
echo -e "\n${AZUL}═══ [2/10] Definindo configurações...${SEM_COR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="/var/www/html/seederlinux"

# Banco de dados - valores fixos para consistência
DB_NAME="seederlinux"
DB_USER="seederlinux"
DB_PASS="seederlinux123"

# Admin padrão
ADMIN_EMAIL="admin@sistema.local"
ADMIN_PASS="Admin@123"
ADMIN_NAME="Administrador"

echo "   Banco: $DB_NAME"
echo "   Usuário BD: $DB_USER"
echo "   Admin: $ADMIN_EMAIL"

# ============================================
# 3. INSTALAR DEPENDÊNCIAS
# ============================================
echo -e "\n${AZUL}═══ [3/10] Instalando dependências...${SEM_COR}"

apt update

case $DISTRO in
    ubuntu|linuxmint|zorin)
        if ! dpkg -l | grep -q php8; then
            apt install -y software-properties-common
            add-apt-repository -y ppa:ondrej/php
            apt update
        fi
        
        apt install -y \
            apache2 \
            libapache2-mod-php8.1 \
            php8.1 \
            php8.1-cli \
            php8.1-common \
            php8.1-pgsql \
            php8.1-curl \
            php8.1-mbstring \
            php8.1-xml \
            php8.1-json \
            postgresql \
            postgresql-client \
            curl \
            git \
            unzip \
            openssl \
            jq \
            rsync
        ;;
    debian)
        apt install -y \
            apache2 \
            libapache2-mod-php \
            php \
            php-cli \
            php-common \
            php-pgsql \
            php-curl \
            php-mbstring \
            php-xml \
            php-json \
            postgresql \
            postgresql-client \
            curl \
            git \
            unzip \
            openssl \
            jq \
            rsync
        ;;
    *)
        echo -e "${VERMELHO}❌ Distribuição não suportada: $DISTRO${SEM_COR}"
        exit 1
        ;;
esac

echo -e "   ${VERDE}✓ Dependências instaladas${SEM_COR}"

# ============================================
# 4. CONFIGURAR POSTGRESQL - USUÁRIO E BANCO
# ============================================
echo -e "\n${AZUL}═══ [4/10] Criando usuário e banco PostgreSQL...${SEM_COR}"

systemctl start postgresql
systemctl enable postgresql

# Detectar versão do PostgreSQL para decidir o método de autenticação
PG_VERSION=$(sudo -u postgres psql -tAc "SHOW server_version;" 2>/dev/null | cut -d. -f1)
if [ "$PG_VERSION" -ge 14 ]; then
    AUTH_METHOD="scram-sha-256"
else
    AUTH_METHOD="md5"
fi
echo "   Versão PostgreSQL: $PG_VERSION -> usando autenticação $AUTH_METHOD"

# Criar usuário e banco (se não existirem)
su - postgres <<PGEOF
-- Garantir que a criptografia de senha seja a padrão (scram para PG14+)
SET password_encryption = 'scram-sha-256';
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';
    ELSE
        ALTER ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';
    END IF;
END
\$\$;
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME') THEN
        CREATE DATABASE $DB_NAME OWNER $DB_USER;
    END IF;
END
\$\$;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
PGEOF

echo -e "   ${VERDE}✓ Banco '$DB_NAME' e usuário '$DB_USER' criados${SEM_COR}"

# ============================================
# 5. CONFIGURAR AUTENTICAÇÃO DO POSTGRESQL
# ============================================
echo -e "\n${AZUL}═══ [5/10] Configurando autenticação PostgreSQL ($AUTH_METHOD)...${SEM_COR}"

PG_HBA=$(sudo -u postgres psql -tAc "SHOW hba_file;")
echo "   Arquivo: $PG_HBA"

if [ -f "$PG_HBA" ]; then
    # Backup
    cp "$PG_HBA" "${PG_HBA}.bak.$(date +%s)"
    
    # Remover entradas anteriores que possam conflitar (para o usuário seederlinux)
    sed -i '/# Regras para seederlinux/d' "$PG_HBA"
    sed -i '/host.*seederlinux.*seederlinux/d' "$PG_HBA"
    sed -i '/local.*seederlinux.*seederlinux/d' "$PG_HBA"
    
    # Inserir regras específicas no INÍCIO do arquivo (prioridade máxima)
    sed -i "1i# Regras para seederlinux (autenticação $AUTH_METHOD)" "$PG_HBA"
    sed -i "2ilocal   seederlinux     seederlinux                             $AUTH_METHOD" "$PG_HBA"
    sed -i "3ihost    seederlinux     seederlinux     127.0.0.1/32            $AUTH_METHOD" "$PG_HBA"
    sed -i "4ihost    seederlinux     seederlinux     ::1/128                 $AUTH_METHOD" "$PG_HBA"
    
    # Ajustar as regras globais para também usarem o mesmo método
    sed -i "s/^local\s\+all\s\+all\s\+.*/local   all             all                                     $AUTH_METHOD/" "$PG_HBA"
    sed -i "s/^host\s\+all\s\+all\s\+127\.0\.0\.1\/32\s\+.*/host    all             all             127.0.0.1\/32            $AUTH_METHOD/" "$PG_HBA"
    sed -i "s/^host\s\+all\s\+all\s\+::1\/128\s\+.*/host    all             all             ::1\/128                 $AUTH_METHOD/" "$PG_HBA"
    
    # Recarregar configuração
    systemctl reload postgresql
    echo -e "   ${VERDE}✓ pg_hba.conf ajustado para $AUTH_METHOD${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ pg_hba.conf não encontrado${SEM_COR}"
fi

# ============================================
# 6. TESTAR E CORRIGIR CONEXÃO COM BANCO
# ============================================
echo -e "\n${AZUL}═══ [6/10] Testando conexão com banco...${SEM_COR}"

testar_conexao() {
    PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'CONEXAO_OK' AS status;" 2>&1 | grep -q "CONEXAO_OK"
}

if testar_conexao; then
    echo -e "   ${VERDE}✓ Conexão com PostgreSQL funcionando corretamente${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ Conexão falhou. Redefinindo senha com método $AUTH_METHOD...${SEM_COR}"
    
    # Redefinir a senha explicitamente com o método correto
    if [ "$AUTH_METHOD" = "scram-sha-256" ]; then
        su - postgres -c "psql -c \"SET password_encryption = 'scram-sha-256'; ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';\""
    else
        su - postgres -c "psql -c \"SET password_encryption = 'md5'; ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';\""
    fi
    
    systemctl reload postgresql
    
    if testar_conexao; then
        echo -e "   ${VERDE}✓ Conexão restaurada após redefinir senha${SEM_COR}"
    else
        echo -e "   ${VERMELHO}❌ Ainda não foi possível conectar. Verifique o log do PostgreSQL:${SEM_COR}"
        echo "      sudo tail -20 /var/log/postgresql/postgresql-*-main.log"
        exit 1
    fi
fi

# ============================================
# 7. COPIAR ARQUIVOS PARA DIRETÓRIO WEB
# ============================================
echo -e "\n${AZUL}═══ [7/10] Copiando arquivos...${SEM_COR}"

if [ -f "$SCRIPT_DIR/api/config.php" ] || [ -f "$SCRIPT_DIR/api/organizations.php" ]; then
    mkdir -p "$WEB_DIR"
    rsync -av --exclude='.git' --exclude='node_modules' --exclude='*.zip' "$SCRIPT_DIR/" "$WEB_DIR/"
    echo -e "   ${VERDE}✓ Arquivos copiados para $WEB_DIR${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ Diretório do projeto não detectado${SEM_COR}"
    echo "   Certifique-se de executar o script da raiz do projeto SeederLinux"
fi

# ============================================
# 8. CONFIGURAR ARQUIVO DE CONEXÃO
# ============================================
echo -e "\n${AZUL}═══ [8/10] Criando arquivo de conexão...${SEM_COR}"

mkdir -p "$WEB_DIR/api"

cat > "$WEB_DIR/api/config.php" <<'PHPEOF'
<?php
function getDBConnection() {
    $host = 'localhost';
    $port = '5432';
    $dbname = 'DB_NAME_PLACEHOLDER';
    $user = 'DB_USER_PLACEHOLDER';
    $password = 'DB_PASS_PLACEHOLDER';
    
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
            'message' => 'Erro de conexão com o banco de dados'
        ]);
        exit;
    }
}
PHPEOF

sed -i "s/DB_NAME_PLACEHOLDER/$DB_NAME/" "$WEB_DIR/api/config.php"
sed -i "s/DB_USER_PLACEHOLDER/$DB_USER/" "$WEB_DIR/api/config.php"
sed -i "s/DB_PASS_PLACEHOLDER/$DB_PASS/" "$WEB_DIR/api/config.php"

echo -e "   ${VERDE}✓ config.php criado${SEM_COR}"

# ============================================
# 9. EXECUTAR MIGRATIONS E CRIAR ADMIN
# ============================================
echo -e "\n${AZUL}═══ [9/10] Executando migrations e criando admin...${SEM_COR}"

run_sql_file() {
    local file="$1"
    local desc="$2"
    if [ -f "$file" ]; then
        echo "   Executando: $desc"
        PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -f "$file" 2>&1 || \
            echo -e "   ${AMARELO}⚠ Aviso em: $desc (pode ser normal se já executado)${SEM_COR}"
    fi
}

run_sql_file "$WEB_DIR/database/schema.sql" "Schema inicial"
run_sql_file "$WEB_DIR/database/migration_fase2.sql" "Fase 2 (profiles)"
run_sql_file "$WEB_DIR/database/migration_auth.sql" "Autenticação (users)"
run_sql_file "$WEB_DIR/database/migration_variables_v2.sql" "Variáveis (categorias)"

# Criar admin
echo "   Criando usuário administrador..."
HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")

PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" <<EOF
INSERT INTO users (name, email, password_hash, role, active, created_at)
VALUES ('$ADMIN_NAME', '$ADMIN_EMAIL', '$HASH', 'admin_gap', TRUE, NOW())
ON CONFLICT (email) 
DO UPDATE SET password_hash = '$HASH', role = 'admin_gap', active = TRUE;
EOF

echo -e "   ${VERDE}✓ Admin criado/atualizado${SEM_COR}"

# ============================================
# 10. CONFIGURAR APACHE E PERMISSÕES
# ============================================
echo -e "\n${AZUL}═══ [10/10] Configurando Apache...${SEM_COR}"

a2enmod rewrite

cat > /etc/apache2/sites-available/seederlinux.conf <<EOF
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot $WEB_DIR/painel
    
    <Directory $WEB_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    Alias /api $WEB_DIR/api
    <Directory $WEB_DIR/api>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/seederlinux_error.log
    CustomLog \${APACHE_LOG_DIR}/seederlinux_access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf 2>/dev/null || true
a2ensite seederlinux.conf

chown -R www-data:www-data "$WEB_DIR"
chmod -R 755 "$WEB_DIR"
mkdir -p "$WEB_DIR/storage"
chmod -R 775 "$WEB_DIR/storage"
chown -R www-data:www-data "$WEB_DIR/storage"

systemctl restart apache2

echo -e "   ${VERDE}✓ Apache configurado${SEM_COR}"

# ============================================
# VERIFICAÇÃO FINAL
# ============================================
echo -e "\n${AZUL}═══ Verificação Final...${SEM_COR}"

echo "   Testando API..."
API_RESPONSE=$(curl -s http://localhost/api/organizations 2>&1 || echo "FALHA")

if echo "$API_RESPONSE" | grep -q "success\|COMARA\|id\|name"; then
    echo -e "   ${VERDE}✓ API funcionando${SEM_COR}"
elif echo "$API_RESPONSE" | grep -q "login\|token\|auth\|não autenticado\|não autorizado"; then
    echo -e "   ${VERDE}✓ API funcionando (requer autenticação - normal)${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ Resposta inesperada da API: ${API_RESPONSE:0:100}${SEM_COR}"
fi

# ============================================
# RESUMO FINAL
# ============================================
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${VERDE}========================================${SEM_COR}"
echo -e "${VERDE}  ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!  ${SEM_COR}"
echo -e "${VERDE}========================================${SEM_COR}"
echo ""
echo -e "🌐 Painel:     ${AZUL}http://$IP/seederlinux/painel/${SEM_COR}"
echo -e "   ou:         ${AZUL}http://localhost/seederlinux/painel/${SEM_COR}"
echo -e "🔌 API:        ${AZUL}http://$IP/api/${SEM_COR}"
echo -e "🗄️  Banco:      ${AZUL}PostgreSQL - $DB_NAME${SEM_COR}"
echo -e "👤 Usuário BD: ${AZUL}$DB_USER${SEM_COR}"
echo -e "🔑 Senha BD:   ${AZUL}$DB_PASS${SEM_COR}"
echo ""
echo -e "👨‍💼 Admin:      ${AZUL}$ADMIN_EMAIL${SEM_COR}"
echo -e "🔐 Senha:      ${AZUL}$ADMIN_PASS${SEM_COR}"
echo ""
echo -e "${AMARELO}⚠️  Altere a senha do admin no primeiro acesso!${SEM_COR}"
echo -e "${AMARELO}⚠️  Altere a senha do banco em produção!${SEM_COR}"
echo ""
