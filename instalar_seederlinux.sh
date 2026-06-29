#!/bin/bash
# =============================================================================
# instalar_seederlinux.sh - Instalação Completa do SeederLinux Lite
# =============================================================================
# Este script:
#   1. Detecta o sistema (Ubuntu, Debian, Mint, Zorin)
#   2. Instala Apache, PHP 8.1+ e PostgreSQL
#   3. Cria banco de dados e executa TODAS as migrations
#   4. Cria usuário admin com hash bcrypt
#   5. Configura permissões e reinicia serviços
#   6. Exibe resumo final
# =============================================================================
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
echo -e "${AZUL}═══ [1/8] Detectando sistema...${SEM_COR}"

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
echo -e "\n${AZUL}═══ [2/8] Definindo configurações...${SEM_COR}"

# Diretório onde o SeederLinux está/estará
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="/var/www/html/seederlinux"

# Banco de dados
DB_NAME="seederlinux"
DB_USER="seederlinux"
DB_PASS="seederlinux_$(openssl rand -hex 6)"

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
echo -e "\n${AZUL}═══ [3/8] Instalando dependências...${SEM_COR}"

apt update

case $DISTRO in
    ubuntu|linuxmint|zorin)
        # Adicionar repositório PHP se necessário
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
            jq
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
            jq
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
echo -e "\n${AZUL}═══ [4/8] Configurando PostgreSQL...${SEM_COR}"

# Iniciar e habilitar serviço
systemctl start postgresql
systemctl enable postgresql

# Criar usuário e banco
su - postgres <<EOF
psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
    psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
    psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
EOF

echo -e "   ${VERDE}✓ Banco '$DB_NAME' criado (usuário: $DB_USER)${SEM_COR}"

# ============================================
# 5. COPIAR ARQUIVOS PARA DIRETÓRIO WEB
# ============================================
echo -e "\n${AZUL}═══ [5/8] Copiando arquivos...${SEM_COR}"

# Se o script está rodando do diretório do projeto
if [ -f "$SCRIPT_DIR/api/config.php" ]; then
    mkdir -p "$WEB_DIR"
    rsync -av --exclude='.git' --exclude='node_modules' "$SCRIPT_DIR/" "$WEB_DIR/"
    echo -e "   ${VERDE}✓ Arquivos copiados de $SCRIPT_DIR${SEM_COR}"
else
    echo -e "   ${AMARELO}⚠ Script não está no diretório do projeto${SEM_COR}"
    echo "   Certifique-se de que os arquivos estão em $WEB_DIR"
fi

# ============================================
# 6. CONFIGURAR CONEXÃO COM BANCO
# ============================================
echo -e "\n${AZUL}═══ [6/8] Configurando conexão com banco...${SEM_COR}"

CONFIG_FILE="$WEB_DIR/api/config.php"

# Criar config.php se não existir
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<'PHPEOF'
<?php
// Configuração de conexão com PostgreSQL
function getDBConnection() {
    $host = 'DB_HOST';
    $dbname = 'DB_NAME';
    $user = 'DB_USER';
    $password = 'DB_PASS';
    
    try {
        $pdo = new PDO(
            "pgsql:host=$host;dbname=$dbname",
            $user,
            $password,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        return $pdo;
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => 'Erro de conexão com o banco de dados']);
        exit;
    }
}
PHPEOF
fi

# Substituir credenciais
sed -i "s/DB_HOST/'localhost'/" "$CONFIG_FILE"
sed -i "s/DB_NAME/'$DB_NAME'/" "$CONFIG_FILE"
sed -i "s/DB_USER/'$DB_USER'/" "$CONFIG_FILE"
sed -i "s/DB_PASS/'$DB_PASS'/" "$CONFIG_FILE"

echo -e "   ${VERDE}✓ Conexão configurada em api/config.php${SEM_COR}"

# ============================================
# 7. EXECUTAR MIGRATIONS DO BANCO
# ============================================
echo -e "\n${AZUL}═══ [7/8] Executando migrations...${SEM_COR}"

run_sql_file() {
    local file="$1"
    local desc="$2"
    if [ -f "$file" ]; then
        echo "   Executando: $desc"
        PGPASSWORD=$DB_PASS psql -h localhost -U "$DB_USER" -d "$DB_NAME" -f "$file" > /dev/null 2>&1
        echo -e "   ${VERDE}✓ $desc${SEM_COR}"
    else
        echo -e "   ${AMARELO}⚠ Arquivo não encontrado: $file${SEM_COR}"
    fi
}

# Ordem correta das migrations
run_sql_file "$WEB_DIR/database/schema.sql" "Schema inicial"
run_sql_file "$WEB_DIR/database/migration_fase2.sql" "Migração Fase 2 (profiles)"
run_sql_file "$WEB_DIR/database/migration_auth.sql" "Migração Autenticação (users)"
run_sql_file "$WEB_DIR/database/migration_variables_v2.sql" "Migração Variáveis (categorias)"

# ============================================
# 8. CRIAR USUÁRIO ADMIN
# ============================================
echo ""
echo "   Criando usuário administrador padrão..."

# Gerar hash bcrypt
HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")

# Inserir ou atualizar admin
PGPASSWORD=$DB_PASS psql -h localhost -U "$DB_USER" -d "$DB_NAME" <<EOF
INSERT INTO users (name, email, password_hash, role, active, created_at)
VALUES ('$ADMIN_NAME', '$ADMIN_EMAIL', '$HASH', 'admin_gap', TRUE, NOW())
ON CONFLICT (email) 
DO UPDATE SET 
    password_hash = '$HASH',
    role = 'admin_gap',
    active = TRUE;
EOF

echo -e "   ${VERDE}✓ Admin criado: $ADMIN_EMAIL${SEM_COR}"

# ============================================
# 9. CONFIGURAR APACHE
# ============================================
echo -e "\n${AZUL}═══ [8/8] Configurando Apache...${SEM_COR}"

# Habilitar mod_rewrite
a2enmod rewrite

# Criar virtual host
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

# Desabilitar site padrão e habilitar o novo
a2dissite 000-default.conf 2>/dev/null || true
a2ensite seederlinux.conf

# Configurar permissões
chown -R www-data:www-data "$WEB_DIR"
chmod -R 755 "$WEB_DIR"
mkdir -p "$WEB_DIR/storage"
chmod -R 775 "$WEB_DIR/storage"
chown -R www-data:www-data "$WEB_DIR/storage"

# Reiniciar Apache
systemctl restart apache2

echo -e "   ${VERDE}✓ Apache configurado${SEM_COR}"

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
echo -e "${AMARELO}⚠️  IMPORTANTE: Altere a senha do admin no primeiro acesso!${SEM_COR}"
echo ""
echo -e "📁 Logs:       /var/log/apache2/seederlinux_*.log"
echo -e "📁 Arquivos:   $WEB_DIR"
echo ""
echo -e "${AZUL}⚠️  Guarde as senhas acima. Elas não serão exibidas novamente.${SEM_COR}"
