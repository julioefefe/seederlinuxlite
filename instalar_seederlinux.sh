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

DB_NAME="seederlinux"
DB_USER="seederlinux"
DB_PASS="seederlinux123"

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
# 4. CONFIGURAR POSTGRESQL
# ============================================
echo -e "\n${AZUL}═══ [4/10] Configurando PostgreSQL...${SEM_COR}"

systemctl start postgresql
systemctl enable postgresql

# Detectar versão do PostgreSQL
PG_VERSION=$(sudo -u postgres psql -tAc "SHOW server_version;" 2>/dev/null | cut -d. -f1)
if [ "$PG_VERSION" -ge 14 ]; then
    AUTH_METHOD="scram-sha-256"
else
    AUTH_METHOD="md5"
fi
echo "   Versão PostgreSQL: $PG_VERSION -> método $AUTH_METHOD"

# Criar/alterar usuário e banco
su - postgres <<PGEOF
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
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
PGEOF

echo -e "   ${VERDE}✓ Usuário e banco configurados${SEM_COR}"

# ============================================
# 5. CORRIGIR pg_hba.conf (MÉTODO SEGURO)
# ============================================
echo -e "\n${AZUL}═══ [5/10] Ajustando pg_hba.conf...${SEM_COR}"

PG_HBA=$(sudo -u postgres psql -tAc "SHOW hba_file;")
echo "   Arquivo: $PG_HBA"

if [ -f "$PG_HBA" ]; then
    # Backup
    cp "$PG_HBA" "${PG_HBA}.bak.$(date +%s)"
    
    # Escrever um novo arquivo com as regras corretas
    cat > "${PG_HBA}.new" <<EOF
# Regras específicas para o SeederLinux
local   seederlinux     seederlinux                             $AUTH_METHOD
host    seederlinux     seederlinux     127.0.0.1/32            $AUTH_METHOD
host    seederlinux     seederlinux     ::1/128                 $AUTH_METHOD

# Regras globais
local   all             all                                     $AUTH_METHOD
host    all             all             127.0.0.1/32            $AUTH_METHOD
host    all             all             ::1/128                 $AUTH_METHOD
EOF

    # Concatenar o restante do arquivo original (removendo linhas que já inserimos)
    grep -vE '^(local|host)\s+(seederlinux|all)\s+(seederlinux|all)\s' "$PG_HBA" | \
        grep -v '^#' | cat "${PG_HBA}.new" - > "${PG_HBA}.tmp"
    mv "${PG_HBA}.tmp" "$PG_HBA"
    rm -f "${PG_HBA}.new"
    
    systemctl reload postgresql
    echo -e "   ${VERDE}✓ pg_hba.conf ajustado${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ pg_hba.conf não encontrado${SEM_COR}"
fi

# ============================================
# 6. TESTAR CONEXÃO
# ============================================
echo -e "\n${AZUL}═══ [6/10] Testando conexão...${SEM_COR}"

if PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'CONEXAO_OK' AS status;" 2>&1 | grep -q "CONEXAO_OK"; then
    echo -e "   ${VERDE}✓ Conexão OK${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ Conexão falhou. Redefinindo senha...${SEM_COR}"
    su - postgres -c "psql -c \"SET password_encryption = '$AUTH_METHOD'; ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';\""
    systemctl reload postgresql
    if PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'CONEXAO_OK' AS status;" 2>&1 | grep -q "CONEXAO_OK"; then
        echo -e "   ${VERDE}✓ Conexão restaurada${SEM_COR}"
    else
        echo -e "   ${VERMELHO}❌ Falha na conexão. Verifique o log:${SEM_COR}"
        echo "   sudo tail -20 /var/log/postgresql/postgresql-*-main.log"
        exit 1
    fi
fi

# ============================================
# 7. COPIAR ARQUIVOS
# ============================================
echo -e "\n${AZUL}═══ [7/10] Copiando arquivos...${SEM_COR}"

if [ -f "$SCRIPT_DIR/api/config.php" ] || [ -f "$SCRIPT_DIR/api/organizations.php" ]; then
    mkdir -p "$WEB_DIR"
    rsync -av --exclude='.git' --exclude='node_modules' --exclude='*.zip' "$SCRIPT_DIR/" "$WEB_DIR/"
    echo -e "   ${VERDE}✓ Arquivos copiados${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ Diretório do projeto não encontrado${SEM_COR}"
fi

# ============================================
# 8. CONFIG.PHP
# ============================================
echo -e "\n${AZUL}═══ [8/10] Criando config.php...${SEM_COR}"

mkdir -p "$WEB_DIR/api"

cat > "$WEB_DIR/api/config.php" <<PHPEOF
<?php
function getDBConnection() {
    \$host = 'localhost';
    \$port = '5432';
    \$dbname = '$DB_NAME';
    \$user = '$DB_USER';
    \$password = '$DB_PASS';
    
    try {
        \$dsn = "pgsql:host=\$host;port=\$port;dbname=\$dbname";
        \$pdo = new PDO(\$dsn, \$user, \$password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false
        ]);
        return \$pdo;
    } catch (PDOException \$e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Erro de conexão']);
        exit;
    }
}
PHPEOF

echo -e "   ${VERDE}✓ config.php criado${SEM_COR}"

# ============================================
# 9. MIGRATIONS E ADMIN
# ============================================
echo -e "\n${AZUL}═══ [9/10] Executando migrations...${SEM_COR}"

run_sql() {
    local file="$1"
    local desc="$2"
    if [ -f "$file" ]; then
        echo "   $desc..."
        PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -f "$file" 2>&1 || \
            echo -e "   ${AMARELO}⚠ Aviso em $desc (pode já existir)${SEM_COR}"
    fi
}

run_sql "$WEB_DIR/database/schema.sql" "Schema inicial"
run_sql "$WEB_DIR/database/migration_fase2.sql" "Fase 2"
run_sql "$WEB_DIR/database/migration_auth.sql" "Autenticação"
run_sql "$WEB_DIR/database/migration_variables_v2.sql" "Variáveis"

HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")
PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c \
    "INSERT INTO users (name, email, password_hash, role, active, created_at) 
     VALUES ('$ADMIN_NAME', '$ADMIN_EMAIL', '$HASH', 'admin_gap', TRUE, NOW()) 
     ON CONFLICT (email) DO UPDATE SET password_hash = '$HASH', active = TRUE;"

echo -e "   ${VERDE}✓ Admin configurado${SEM_COR}"

# ============================================
# 10. APACHE
# ============================================
echo -e "\n${AZUL}═══ [10/10] Configurando Apache...${SEM_COR}"

a2enmod rewrite

cat > /etc/apache2/sites-available/seederlinux.conf <<EOF
<VirtualHost *:80>
    DocumentRoot $WEB_DIR/painel
    <Directory $WEB_DIR>
        AllowOverride All
        Require all granted
    </Directory>
    Alias /api $WEB_DIR/api
    <Directory $WEB_DIR/api>
        Require all granted
    </Directory>
</VirtualHost>
EOF

a2dissite 000-default.conf 2>/dev/null || true
a2ensite seederlinux.conf
chown -R www-data:www-data "$WEB_DIR"
chmod -R 755 "$WEB_DIR"
mkdir -p "$WEB_DIR/storage" && chmod -R 775 "$WEB_DIR/storage" && chown -R www-data:www-data "$WEB_DIR/storage"
systemctl restart apache2

echo -e "   ${VERDE}✓ Apache configurado${SEM_COR}"

# ============================================
# VERIFICAÇÃO FINAL
# ============================================
echo -e "\n${AZUL}═══ Verificação Final...${SEM_COR}"
curl -s http://localhost/api/organizations && echo -e "\n${VERDE}✓ API respondendo${SEM_COR}" || echo -e "${AMARELO}⚠ API não responde (pode precisar de autenticação)${SEM_COR}"

IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${VERDE}✅ Instalação concluída!${SEM_COR}"
echo -e "🌐 Painel: http://$IP/seederlinux/painel/"
echo -e "🔑 Admin: $ADMIN_EMAIL / $ADMIN_PASS"
