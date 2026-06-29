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
    
    // Iniciais do usuário
    const initials = user.name.split(' ').map(n => n[0]).join('').toUpperCase().substring(0, 2);
    document.getElementById('user-initials').textContent = initials;

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
        if (data.length === 0) {
            variablesList.innerHTML = '<div class="text-center py-10 text-slate-400">Nenhuma variável nesta categoria.</div>';
            return;
        }
        let html = '<div class="space-y-4">';
        data.forEach(v => {
            const isMissing = v.required && !v.value && !v.default_value;
            const valueDisplay = v.value || (v.default_value ? `${v.default_value} (padrão)` : 'Não definido');
            const statusColor = isMissing ? 'bg-red-100 text-red-600' : (v.required ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-500');
            const statusText = isMissing ? 'Pendente' : (v.required ? 'Obrigatória' : 'Opcional');
            
            html += `
            <div class="p-4 rounded-2xl border border-slate-100 bg-slate-50/30 hover:bg-white hover:shadow-sm transition-all">
                <div class="flex justify-between items-start mb-1">
                    <code class="text-sm font-bold ${v.required ? 'text-slate-900' : 'text-slate-600'}">${v.name}</code>
                    <span class="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full ${statusColor}">${statusText}</span>
                </div>
                <div class="text-sm ${isMissing ? 'text-slate-400 italic' : 'text-slate-700'} truncate">
                    ${valueDisplay}
                </div>
                <div class="mt-2 text-[10px] text-slate-400 uppercase tracking-wider font-semibold">
                    ${v.category || 'geral'}
                </div>
            </div>`;
        });
        html += '</div>';
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
        scriptsList.innerHTML = '<div class="text-slate-400 text-sm">Carregando módulos...</div>';
        authFetch(`../api/scripts.php?org=${orgId}`)
            .then(res => res.json())
            .then(data => {
                scriptsList.innerHTML = '';
                data.forEach(s => {
                    const label = document.createElement('label');
                    label.className = 'flex items-center p-3 rounded-xl border border-slate-100 bg-slate-50/50 hover:bg-white hover:border-cyan-200 cursor-pointer transition-all group';
                    label.innerHTML = `
                        <input type="checkbox" name="scripts" value="${s.id}" class="w-4 h-4 text-cyan-500 rounded border-slate-300 focus:ring-cyan-500" ${s.is_core ? 'checked' : ''}>
                        <div class="ml-3">
                            <span class="text-sm font-semibold text-slate-700 group-hover:text-slate-900">${s.name}</span>
                            ${s.is_core ? '<span class="ml-2 text-[10px] bg-cyan-100 text-cyan-600 px-1.5 py-0.5 rounded font-bold uppercase">Core</span>' : ''}
                        </div>
                    `;
                    scriptsList.appendChild(label);
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
