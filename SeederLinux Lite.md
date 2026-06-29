# Documentação do Sistema Minimalista

## **SeederLinux Lite** (versão simplificada)

---

## 1. PRD – Visão Geral

**Objetivo:** Gerenciar scripts de provisionamento para múltiplas Organizações (OMs) de forma centralizada, substituindo variáveis dinamicamente e distribuindo para estações Linux.

**Princípios:**
- Simplicidade máxima: PHP + PostgreSQL + Shell
- Sem Docker, sem containers
- Offline-first: scripts funcionam mesmo sem rede
- Multi-OM: cada organização tem suas variáveis, branding e scripts
- Modularidade: scripts são independentes e reutilizáveis
- Cache de senha AD (SSSD/Winbind) configurável

**Funcionalidades MVP:**
- Cadastro de OMs
- Catálogo de variáveis por OM
- Upload e versionamento de scripts
- Substituição de placeholders `{{VARIAVEL}}` por valores reais
- Geração de "bundle" (script final pronto para executar)
- API simples para consulta de variáveis
- Painel web básico para administração

---

## 2. Arquitetura Simplificada

```
Servidor Central (PHP + PostgreSQL)
│
├── painel/          (HTML5 + CSS + JavaScript vanilla)
├── api/             (endpoints PHP)
├── scripts/         (scripts shell modulares)
├── lib/             (funções PHP compartilhadas)
└── storage/         (uploads, logs)
```

**Tecnologias:**
- **Backend:** PHP 8+ (sem framework, puro)
- **Banco:** PostgreSQL 16+
- **Frontend:** HTML5, CSS3, JavaScript (fetch API)
- **Scripts:** Bash shell (com placeholders)
- **Agente:** Python 3 (script simples que consulta API e executa bundle)

---

## 3. Modelo de Dados (Simplificado)

### Tabelas principais:

**organizations**
| Campo | Tipo |
|-------|------|
| id | SERIAL |
| name | VARCHAR(100) |
| acronym | VARCHAR(20) UNIQUE |
| domain | VARCHAR(100) |
| active | BOOLEAN |

**variables**
| Campo | Tipo |
|-------|------|
| id | SERIAL |
| organization_id | INT (FK) |
| name | VARCHAR(100) |
| value | TEXT |
| type | VARCHAR(20) (string, int, bool, json) |
| description | TEXT |

**scripts**
| Campo | Tipo |
|-------|------|
| id | SERIAL |
| organization_id | INT (FK, nullable) |
| name | VARCHAR(200) |
| content | TEXT |
| version | INT |
| is_core | BOOLEAN |

**deploy_bundles**
| Campo | Tipo |
|-------|------|
| id | SERIAL |
| organization_id | INT |
| generated_at | TIMESTAMP |
| content | TEXT (script final) |

---

## 4. Catálogo de Módulos Core (Scripts)

Esses scripts são fornecidos pelo sistema e imutáveis:

- `core_domain.sh` – ingresso no AD (SSSD/Winbind)
- `core_files.sh` – montagem de compartilhamentos
- `core_browser.sh` – políticas de navegador
- `core_printers.sh` – configuração CUPS
- `core_inventory.sh` – OCS Inventory
- `core_remote.sh` – RustDesk/VNC
- `core_branding.sh` – wallpaper, tema, logotipo
- `core_offline_auth.sh` – cache de credenciais

Cada script usa placeholders: `{{DOMINIO}}`, `{{DC_IP}}`, etc.

---

## 5. Catálogo de Variáveis

| Nome | Descrição | Tipo |
|------|-----------|------|
| DOMINIO | Domínio AD | string |
| DOMINIO_NETBIOS | Nome NetBIOS | string |
| DC_IP | IP do controlador | string |
| DNS_PRIMARIO | DNS principal | string |
| PROXY_URL | Proxy corporativo | string |
| HOMEPAGE | Página inicial navegador | string |
| OCS_SERVER | Servidor OCS | string |
| PRINT_SERVER | Servidor CUPS | string |
| OFFLINE_AUTH_DAYS | Dias de cache offline | int |

---

## 6. Funcionamento do Provisionamento

1. Admin seleciona uma OM e os módulos desejados
2. Sistema carrega as variáveis da OM
3. Scripts são concatenados e os placeholders substituídos
4. Bundle final é gerado (arquivo .sh)
5. Agente na estação baixa o bundle e executa

**Exemplo de substituição:**
```bash
# Antes
echo "Domínio: {{DOMINIO}}"
# Depois
echo "Domínio: comara.intraer"
```

---

## 7. API REST (PHP)

Endpoints simples:

- `GET /api/organizations` – lista OMs
- `GET /api/organizations/{id}/variables` – variáveis da OM
- `GET /api/scripts?org={id}` – scripts disponíveis
- `POST /api/generate-bundle` – gera bundle
- `POST /api/checkin` – check-in do agente
- `GET /api/bundle/{id}` – download do bundle

---

## 8. Frontend Web

Painel simples com:
- Lista de OMs
- Gerenciar variáveis (adicionar/editar)
- Upload de scripts personalizados
- Visualizar scripts Core
- Gerar bundle (botão "Provisionar")

Tecnologias: HTML5 + CSS (PicoCSS ou Water.css) + JavaScript (fetch)

---

## 9. Plano de Implementação

### Fase 1 – Estrutura Base (hoje)
- [x] Documentação criada
- [ ] Criar banco de dados PostgreSQL
- [ ] Criar API PHP básica (CRUD de organizações e variáveis)
- [ ] Criar frontend HTML+JS para cadastro de variáveis
- [ ] Criar script de exemplo com placeholders

### Fase 2 – Módulos Core
- [ ] Implementar `core_domain.sh` com suporte a SSSD e Winbind
- [ ] Implementar `core_offline_auth.sh`
- [ ] Implementar `core_branding.sh`
- [ ] Adaptar seus scripts atuais para placeholders

### Fase 3 – Provisionamento
- [ ] Lógica de substituição de variáveis
- [ ] Geração de bundle
- [ ] Agente Python simples para check-in e execução

---

## 10. Próximos Passos

Posso agora:
1. Criar o script SQL para as tabelas
2. Criar a estrutura de diretórios
3. Implementar a API PHP passo a passo
4. Adaptar seus scripts existentes (ingreca_mint_v2.sh, etc.) para usar variáveis do banco

Qual parte você gostaria de começar?