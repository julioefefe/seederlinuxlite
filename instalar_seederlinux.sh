#!/bin/bash
# =============================================================================
# instalar_seederlinux.sh - Instalação Completa do SeederLinux Lite
# =============================================================================
# Uso: sudo ./instalar_seederlinux.sh
# =============================================================================

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

# Detectar versão do PostgreSQL
PG_MAJOR=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1)
echo "   PostgreSQL: versão $PG_MAJOR"

# ============================================
# 2. CONFIGURAÇÕES
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
# 4. INICIAR POSTGRESQL
# ============================================
echo -e "\n${AZUL}═══ [4/10] Iniciando PostgreSQL...${SEM_COR}"

systemctl start postgresql
systemctl enable postgresql
sleep 2

if systemctl is-active --quiet postgresql; then
    echo -e "   ${VERDE}✓ PostgreSQL ativo${SEM_COR}"
else
    echo -e "   ${VERMELHO}❌ PostgreSQL não iniciou${SEM_COR}"
    systemctl status postgresql --no-pager
    exit 1
fi

# ============================================
# 5. CRIAR USUÁRIO E BANCO (comandos separados)
# ============================================
echo -e "\n${AZUL}═══ [5/10] Criando usuário e banco...${SEM_COR}"

# Criar usuário (se não existir)
if ! su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'\"" 2>/dev/null | grep -q 1; then
    echo "   Criando usuário $DB_USER..."
    su - postgres -c "psql -c \"CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';\"" 2>&1
    echo -e "   ${VERDE}✓ Usuário criado${SEM_COR}"
else
    echo "   Usuário $DB_USER já existe. Atualizando senha..."
    su - postgres -c "psql -c \"ALTER ROLE $DB_USER WITH PASSWORD '$DB_PASS';\"" 2>&1
    echo -e "   ${VERDE}✓ Senha atualizada${SEM_COR}"
fi

# Criar banco (se não existir)
if ! su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='$DB_NAME'\"" 2>/dev/null | grep -q 1; then
    echo "   Criando banco $DB_NAME..."
    su - postgres -c "psql -c \"CREATE DATABASE $DB_NAME OWNER $DB_USER;\"" 2>&1
    echo -e "   ${VERDE}✓ Banco criado${SEM_COR}"
else
    echo "   Banco $DB_NAME já existe."
fi

# Garantir privilégios
echo "   Configurando privilégios..."
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;\"" 2>&1
su - postgres -c "psql -d $DB_NAME -c \"GRANT ALL ON SCHEMA public TO $DB_USER;\"" 2>&1
su - postgres -c "psql -d $DB_NAME -c \"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;\"" 2>&1

echo -e "   ${VERDE}✓ Privilégios configurados${SEM_COR}"

# ============================================
# 6. CONFIGURAR AUTENTICAÇÃO MD5
# ============================================
echo -e "\n${AZUL}═══ [6/10] Configurando autenticação PostgreSQL...${SEM_COR}"

PG_HBA=$(su - postgres -c "psql -tAc 'SHOW hba_file;'" 2>/dev/null | tr -d ' ')
echo "   Arquivo pg_hba.conf: $PG_HBA"

if [ -n "$PG_HBA" ] && [ -f "$PG_HBA" ]; then
    # Backup
    cp "$PG_HBA" "${PG_HBA}.bak.$(date +%s)"
    echo "   Backup criado."
    
    # Ajustar autenticação local
    if grep -q "^local\s\+all\s\+all\s\+peer" "$PG_HBA"; then
        sed -i 's/^local\s\+all\s\+all\s\+peer/local   all             all                                     md5/' "$PG_HBA"
        echo "   local: peer -> md5"
    fi
    
    # Ajustar autenticação IPv4
    if grep -q "^host\s\+all\s\+all\s\+127\.0\.0\.1/32\s\+scram-sha-256" "$PG_HBA"; then
        sed -i 's/^host\s\+all\s\+all\s\+127\.0\.0\.1\/32\s\+scram-sha-256/host    all             all             127.0.0.1\/32            md5/' "$PG_HBA"
        echo "   IPv4: scram-sha-256 -> md5"
    fi
    
    # Ajustar autenticação IPv6
    if grep -q "^host\s\+all\s\+all\s\+::1/128\s\+scram-sha-256" "$PG_HBA"; then
        sed -i 's/^host\s\+all\s\+all\s\+::1\/128\s\+scram-sha-256/host    all             all             ::1\/128                 md5/' "$PG_HBA"
        echo "   IPv6: scram-sha-256 -> md5"
    fi
    
    systemctl restart postgresql
    sleep 2
    echo -e "   ${VERDE}✓ PostgreSQL reiniciado com md5${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ pg_hba.conf não encontrado. Tentando localizar...${SEM_COR}"
    PG_HBA=$(find /etc/postgresql -name pg_hba.conf 2>/dev/null | head -1)
    if [ -n "$PG_HBA" ]; then
        echo "   Encontrado: $PG_HBA"
        cp "$PG_HBA" "${PG_HBA}.bak.$(date +%s)"
        sed -i 's/peer$/md5/' "$PG_HBA"
        sed -i 's/scram-sha-256$/md5/' "$PG_HBA"
        systemctl restart postgresql
        sleep 2
    fi
fi

# ============================================
# 7. TESTAR CONEXÃO
# ============================================
echo -e "\n${AZUL}═══ [7/10] Testando conexão com banco...${SEM_COR}"

CONEXAO_OK=false

# Teste 1: via TCP
if PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'OK' AS status;" 2>/dev/null | grep -q "OK"; then
    echo -e "   ${VERDE}✓ Conexão TCP funcionando${SEM_COR}"
    CONEXAO_OK=true
fi

# Teste 2: via socket (fallback)
if ! $CONEXAO_OK; then
    if su - postgres -c "psql -d $DB_NAME -c \"SELECT 'OK' AS status;\"" 2>/dev/null | grep -q "OK"; then
        echo -e "   ${AMARELO}⚠ Conexão socket funciona, TCP falhou${SEM_COR}"
        echo "   Tentando configurar trust temporário..."
        
        if [ -n "$PG_HBA" ] && [ -f "$PG_HBA" ]; then
            sed -i 's/^local\s\+all\s\+all\s\+.*/local   all             all                                     trust/' "$PG_HBA"
            sed -i 's/^host\s\+all\s\+all\s\+127\.0\.0\.1\/32\s\+.*/host    all             all             127.0.0.1\/32            trust/' "$PG_HBA"
            systemctl restart postgresql
            sleep 2
            
            if PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'OK' AS status;" 2>/dev/null | grep -q "OK"; then
                echo -e "   ${VERDE}✓ Conexão funcionando com trust${SEM_COR}"
                CONEXAO_OK=true
            fi
        fi
    fi
fi

if ! $CONEXAO_OK; then
    echo -e "   ${VERMELHO}❌ ATENÇÃO: Não foi possível conectar ao banco${SEM_COR}"
    echo "   A instalação continuará, mas verifique manualmente."
fi

# ============================================
# 8. COPIAR ARQUIVOS E CONFIGURAR
# ============================================
echo -e "\n${AZUL}═══ [8/10] Copiando arquivos do projeto...${SEM_COR}"

if [ -f "$SCRIPT_DIR/api/config.php" ] || [ -f "$SCRIPT_DIR/api/organizations.php" ] || [ -d "$SCRIPT_DIR/database" ]; then
    mkdir -p "$WEB_DIR"
    rsync -av --exclude='.git' --exclude='node_modules' --exclude='*.zip' "$SCRIPT_DIR/" "$WEB_DIR/"
    echo -e "   ${VERDE}✓ Arquivos copiados para $WEB_DIR${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ Execute este script da raiz do projeto SeederLinux${SEM_COR}"
fi

# Criar config.php
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
        \$pdo = new PDO(
            \$dsn,
            \$user,
            \$password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false
            ]
        );
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
# 9. EXECUTAR MIGRATIONS E CRIAR ADMIN
# ============================================
echo -e "\n${AZUL}═══ [9/10] Executando migrations...${SEM_COR}"

run_sql() {
    local file="$1"
    local desc="$2"
    if [ -f "$file" ]; then
        echo "   Rodando: $desc..."
        PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -f "$file" 2>&1 | head -5
        echo -e "   ${VERDE}✓ $desc${SEM_COR}"
    else
        echo -e "   ${AMARELO}⚠ $file não encontrado (pulando)${SEM_COR}"
    fi
}

# Encontrar e executar migrations
for migration in "$WEB_DIR/database/schema.sql" \
                 "$WEB_DIR/database/migration_fase2.sql" \
                 "$WEB_DIR/database/migration_auth.sql" \
                 "$WEB_DIR/database/migration_variables_v2.sql"; do
    run_sql "$migration" "$(basename $migration)"
done

# Criar admin
echo ""
echo "   Criando usuário administrador..."
HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")

PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" <<EOF
INSERT INTO users (name, email, password_hash, role, active, created_at)
VALUES ('$ADMIN_NAME', '$ADMIN_EMAIL', '$HASH', 'admin_gap', TRUE, NOW())
ON CONFLICT (email) 
DO UPDATE SET password_hash = '$HASH', role = 'admin_gap', active = TRUE;
EOF

echo -e "   ${VERDE}✓ Admin: $ADMIN_EMAIL / $ADMIN_PASS${SEM_COR}"

# ============================================
# 10. CONFIGURAR APACHE
# ============================================
echo -e "\n${AZUL}═══ [10/10] Configurando Apache...${SEM_COR}"

a2enmod rewrite 2>/dev/null

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
sleep 1
API_RESPONSE=$(curl -s http://localhost/api/organizations 2>&1 || echo "FALHA")

if echo "$API_RESPONSE" | grep -qE "success|COMARA|id|name"; then
    echo -e "   ${VERDE}✓ API funcionando${SEM_COR}"
elif echo "$API_RESPONSE" | grep -qiE "login|token|auth|não autorizado|401"; then
    echo -e "   ${VERDE}✓ API funcionando (requer autenticação)${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ Resposta da API: ${API_RESPONSE:0:150}${SEM_COR}"
fi

# ============================================
# RESUMO
# ============================================
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${VERDE}========================================${SEM_COR}"
echo -e "${VERDE}  ✅ INSTALAÇÃO CONCLUÍDA!               ${SEM_COR}"
echo -e "${VERDE}========================================${SEM_COR}"
echo ""
echo -e "🌐 Painel:     ${AZUL}http://$IP/seederlinux/painel/${SEM_COR}"
echo -e "🔌 API:        ${AZUL}http://$IP/api/${SEM_COR}"
echo -e "🗄️  Banco:      ${AZUL}$DB_NAME ($DB_USER / $DB_PASS)${SEM_COR}"
echo -e "👨‍💼 Admin:      ${AZUL}$ADMIN_EMAIL / $ADMIN_PASS${SEM_COR}"
echo ""
echo -e "${AMARELO}⚠️  Altere as senhas padrão em produção!${SEM_COR}"
echo -e "📁 Arquivos:   $WEB_DIR"
echo ""
