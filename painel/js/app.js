/**
 * SeederLinux Lite - Frontend Logic (Fase 2)
 */

document.addEventListener('DOMContentLoaded', () => {
    // Verificar Autenticação
    const token = localStorage.getItem('seeder_token');
    if (!token) {
        window.location.href = 'login.html';
        return;
    }

    const user = JSON.parse(localStorage.getItem('seeder_user'));
    document.getElementById('user-name').textContent = user.name;
    document.getElementById('user-role').textContent = user.role;
    document.getElementById('main-nav').classList.remove('hidden');
    if (user.role === 'admin_gap') {
        document.getElementById('nav-users').classList.remove('hidden');
    }

    document.getElementById('btn-logout').addEventListener('click', (e) => {
        e.preventDefault();
        localStorage.removeItem('seeder_token');
        localStorage.removeItem('seeder_user');
        window.location.href = 'login.html';
    });

    // Helper para fetch com Token
    const authFetch = (url, options = {}) => {
        options.headers = options.headers || {};
        options.headers['Authorization'] = `Bearer ${token}`;
        return fetch(url, options).then(res => {
            if (res.status === 401) {
                localStorage.removeItem('seeder_token');
                window.location.href = 'login.html';
            }
            return res;
        });
    };

    const selectOrg = document.getElementById('select-org');
    const sectionDetails = document.getElementById('section-details');
    const variablesList = document.getElementById('variables-list');
    const scriptsList = document.getElementById('scripts-list');
    const btnGenerate = document.getElementById('btn-generate');
    const sectionResult = document.getElementById('section-result');
    const linkDownload = document.getElementById('link-download');
    const filterCategory = document.getElementById('filter-category');
    const selectProfile = document.getElementById('select-profile');
    const manualScriptsDiv = document.getElementById('manual-scripts');

    let allVariables = [];

    // Carregar Categorias
    authFetch('../api/variables.php?action=categories')
        .then(res => res.json())
        .then(data => {
            data.forEach(cat => {
                const opt = document.createElement('option');
                opt.value = cat;
                opt.textContent = cat.charAt(0).toUpperCase() + cat.slice(1);
                filterCategory.appendChild(opt);
            });
        });

    // 1. Carregar Organizações
    authFetch('../api/organizations.php')
        .then(res => res.json())
        .then(data => {
            selectOrg.innerHTML = '<option value="">Selecione uma OM...</option>';
            data.forEach(org => {
                const opt = document.createElement('option');
                opt.value = org.id;
                opt.textContent = `${org.acronym} - ${org.name}`;
                selectOrg.appendChild(opt);
            });
        })
        .catch(err => {
            console.error('Erro ao carregar OMs:', err);
            selectOrg.innerHTML = '<option value="">Erro ao carregar dados</option>';
        });

    // 2. Evento de Seleção de OM
    selectOrg.addEventListener('change', (e) => {
        const orgId = e.target.value;
        if (!orgId) {
            sectionDetails.classList.add('hidden');
            return;
        }

        sectionDetails.classList.remove('hidden');
        sectionResult.classList.add('hidden');
        loadVariables(orgId);
        loadScripts(orgId);
        loadProfiles(orgId);
    });

    filterCategory.addEventListener('change', () => {
        const cat = filterCategory.value;
        const filtered = cat ? allVariables.filter(v => v.category === cat) : allVariables;
        renderVariables(filtered);
    });

    selectProfile.addEventListener('change', () => {
        if (selectProfile.value) {
            manualScriptsDiv.classList.add('hidden');
        } else {
            manualScriptsDiv.classList.remove('hidden');
        }
    });

    function renderVariables(data) {
        let html = '<table><thead><tr><th>Nome / Categoria</th><th>Valor / Padrão</th><th>Status</th></tr></thead><tbody>';
        data.forEach(v => {
            const isMissing = v.required && !v.value && !v.default_value;
            const valueDisplay = v.value || (v.default_value ? `<em>${v.default_value}</em>` : '');
            const nameStyle = v.required ? 'font-weight: bold; color: #d81b60;' : '';
            const statusBadge = v.required ? (isMissing ? '<span class="badge" style="background: #f8d7da; color: #721c24;">Pendente</span>' : '<span class="badge" style="background: #d4edda; color: #155724;">OK</span>') : '';
            
            html += `<tr>
                <td><code style="${nameStyle}">${v.name}</code><br><small>${v.category || 'geral'}</small></td>
                <td>${valueDisplay || '<span style="color:#999">Não definido</span>'}</td>
                <td>${statusBadge}</td>
            </tr>`;
        });
        html += '</tbody></table>';
        variablesList.innerHTML = html;
    }

    // 3. Carregar Variáveis
    function loadVariables(orgId) {
        variablesList.innerHTML = 'Carregando...';
        authFetch(`../api/organizations.php?id=${orgId}&action=variables`)
            .then(res => res.json())
            .then(data => {
                allVariables = data;
                renderVariables(data);
            });
    }

    // 4. Carregar Scripts
    function loadScripts(orgId) {
        scriptsList.innerHTML = 'Carregando...';
        authFetch(`../api/scripts.php?org=${orgId}`)
            .then(res => res.json())
            .then(data => {
                scriptsList.innerHTML = '';
                data.forEach(s => {
                    const div = document.createElement('div');
                    div.className = 'script-item';
                    div.innerHTML = `
                        <input type="checkbox" name="scripts" value="${s.id}" id="script-${s.id}" ${s.is_core ? 'checked' : ''}>
                        <label for="script-${s.id}">${s.name} ${s.is_core ? '(Core)' : ''}</label>
                    `;
                    scriptsList.appendChild(div);
                });
            });
    }

    function loadProfiles(orgId) {
        selectProfile.innerHTML = '<option value="">-- Selecionar Scripts Manualmente --</option>';
        authFetch(`../api/profiles.php?org=${orgId}`)
            .then(res => res.json())
            .then(data => {
                if (Array.isArray(data)) {
                    data.forEach(p => {
                        const opt = document.createElement('option');
                        opt.value = p.id;
                        opt.textContent = p.name;
                        selectProfile.appendChild(opt);
                    });
                }
            });
    }

    // 5. Gerar Bundle
    btnGenerate.addEventListener('click', () => {
        const orgId = selectOrg.value;
        const profileId = selectProfile.value;
        const selectedScripts = Array.from(document.querySelectorAll('input[name="scripts"]:checked'))
                                     .map(cb => parseInt(cb.value));

        if (!profileId && selectedScripts.length === 0) {
            alert('Selecione um perfil ou pelo menos um script!');
            return;
        }

        btnGenerate.disabled = true;
        btnGenerate.textContent = 'Processando...';

        const payload = {
            organization_id: parseInt(orgId)
        };

        if (profileId) {
            payload.profile_id = parseInt(profileId);
        } else {
            payload.script_ids = selectedScripts;
        }

        authFetch('../api/generate-bundle.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        })
        .then(res => res.json())
        .then(data => {
            if (data.error) {
                alert('Erro: ' + data.error);
            } else {
                sectionResult.classList.remove('hidden');
                linkDownload.href = `../${data.download_url}`;
                sectionResult.scrollIntoView({ behavior: 'smooth' });
            }
        })
        .catch(err => alert('Erro na requisição: ' + err))
        .finally(() => {
            btnGenerate.disabled = false;
            btnGenerate.textContent = 'Gerar Bundle de Instalação';
        });
    });
});
