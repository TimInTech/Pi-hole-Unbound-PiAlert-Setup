document.addEventListener('DOMContentLoaded', () => {
    // DOM Elements
    const authOverlay = document.getElementById('auth-overlay');
    const authForm = document.getElementById('auth-form');
    const apiKeyInput = document.getElementById('api-key');
    const authError = document.getElementById('auth-error');
    const dashboard = document.getElementById('dashboard');
    const logoutBtn = document.getElementById('logout-btn');
    const lastUpdateEl = document.getElementById('last-update');

    // API Key management
    let apiKey = sessionStorage.getItem('suite_api_key');

    // Initialization
    if (apiKey) {
        showDashboard();
        fetchData();
    } else {
        showAuth();
    }

    // Event Listeners
    authForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const key = apiKeyInput.value.trim();
        if (!key) return;

        // Verify key by hitting /health
        try {
            const res = await fetch('/health', {
                headers: { 'X-API-Key': key }
            });

            if (res.ok) {
                apiKey = key;
                sessionStorage.setItem('suite_api_key', key);
                authError.classList.add('hidden');
                showDashboard();
                fetchData();
            } else {
                authError.textContent = 'Ungültiger API-Schlüssel.';
                authError.classList.remove('hidden');
            }
        } catch (err) {
            authError.textContent = 'Verbindungsfehler zur API.';
            authError.classList.remove('hidden');
        }
    });

    logoutBtn.addEventListener('click', () => {
        sessionStorage.removeItem('suite_api_key');
        apiKey = null;
        apiKeyInput.value = '';
        showAuth();
    });

    // UI State Management
    function showAuth() {
        authOverlay.classList.remove('hidden');
        dashboard.classList.add('hidden');
        apiKeyInput.focus();
    }

    function showDashboard() {
        authOverlay.classList.add('hidden');
        dashboard.classList.remove('hidden');
    }

    function updateStatusIndicator(elementId, status) {
        const el = document.querySelector('#' + elementId);
        if (!el) return;
        el.className = 'status-indicator ' + status;
    }

    function updateElementText(elementId, text) {
        const el = document.querySelector('#' + elementId);
        if (el) el.textContent = text;
    }

    // Data Fetching
    async function apiFetch(endpoint) {
        try {
            const res = await fetch(endpoint, {
                headers: { 'X-API-Key': apiKey }
            });
            if (res.status === 401) {
                logoutBtn.click();
                throw new Error('Unauthorized');
            }
            if (!res.ok) throw new Error('API Error');
            return await res.json();
        } catch (error) {
            console.error(`Error fetching ${endpoint}:`, error);
            return null;
        }
    }

    async function fetchData() {
        const now = new Date();
        updateElementText('last-update', `Letzte Aktualisierung: ${now.toLocaleTimeString()}`);

        updateStatusIndicator('overall-status .status-indicator', 'loading');
        updateElementText('overall-status .status-text', 'Wird geladen...');

        const [health, urls, pihole, unbound, netalertx, stats] = await Promise.all([
            apiFetch('/health'),
            apiFetch('/urls'),
            apiFetch('/pihole'),
            apiFetch('/unbound'),
            apiFetch('/netalertx'),
            apiFetch('/stats')
        ]);

        let allHealthy = true;

        // Process System Health
        if (health) {
            updateStatusIndicator('system-status-indicator', 'healthy');
            updateElementText('system-uptime', formatUptime(health.uptime_seconds));
            updateElementText('system-version', health.version);
        } else {
            updateStatusIndicator('system-status-indicator', 'error');
            allHealthy = false;
        }

        if (urls) {
            updateElementText('system-ip', urls.host_ip);
            const linkPihole = document.getElementById('link-pihole-admin');
            if (linkPihole) linkPihole.href = urls.pihole_admin;

            const linkNetalertx = document.getElementById('link-netalertx');
            if (linkNetalertx) linkNetalertx.href = urls.netalertx;
        }

        // Process Pi-hole
        if (pihole) {
            if (pihole.ftl_active) {
                updateStatusIndicator('pihole-status-indicator', 'healthy');
                updateElementText('pihole-status', 'Aktiv (FTL läuft)');
            } else {
                updateStatusIndicator('pihole-status-indicator', 'error');
                updateElementText('pihole-status', 'Fehler (FTL inaktiv)');
                allHealthy = false;
            }
            updateElementText('pihole-version', pihole.pihole_version);

            let upstreamsStr = pihole.upstreams === null ? 'Unbekannt (nicht lesbar)' : 'Keine konfiguriert';
            if (pihole.upstreams && pihole.upstreams.length > 0) {
                upstreamsStr = pihole.upstreams.join(', ');

                // Verify Unbound upstream if unbound is available
                if (unbound && unbound.port) {
                    const expectedUpstream = `127.0.0.1#${unbound.port}`;
                    if (!pihole.upstreams.includes(expectedUpstream)) {
                        upstreamsStr += ' (Warnung: Unbound nicht konfiguriert!)';
                        if (pihole.ftl_active) updateStatusIndicator('pihole-status-indicator', 'warning');
                        allHealthy = false;
                    }
                }
            } else {
                if (pihole.ftl_active) updateStatusIndicator('pihole-status-indicator', 'warning');
                allHealthy = false;
            }
            updateElementText('pihole-upstreams', upstreamsStr);

        } else {
            updateStatusIndicator('pihole-status-indicator', 'unavailable');
            updateElementText('pihole-status', 'Nicht erreichbar');
            allHealthy = false;
        }

        if (stats) {
            updateElementText('pihole-recent-queries', stats.recent_queries ?? 'Nicht verfügbar');
        }

        // Process Unbound
        if (unbound) {
            updateElementText('unbound-port', unbound.port);
            if (unbound.service_active) {
                updateElementText('unbound-status', 'Aktiv');
                if (unbound.dig_ok) {
                    updateStatusIndicator('unbound-status-indicator', 'healthy');
                    updateElementText('unbound-dig', 'Erfolgreich');
                } else {
                    updateStatusIndicator('unbound-status-indicator', 'warning');
                    updateElementText('unbound-dig', 'Fehlgeschlagen');
                    allHealthy = false;
                }
            } else {
                updateStatusIndicator('unbound-status-indicator', 'error');
                updateElementText('unbound-status', 'Inaktiv');
                updateElementText('unbound-dig', '-');
                allHealthy = false;
            }
            updateElementText('unbound-dig-result', unbound.dig_result || '-');
        } else {
            updateStatusIndicator('unbound-status-indicator', 'unavailable');
            updateElementText('unbound-status', 'Nicht erreichbar');
            allHealthy = false;
        }

        // Process NetAlertX (Optional)
        if (netalertx) {
            updateElementText('netalertx-port', netalertx.port);
            if (netalertx.http_reachable) {
                updateStatusIndicator('netalertx-status-indicator', 'healthy');
                updateElementText('netalertx-status', 'Erreichbar');
            } else {
                updateStatusIndicator('netalertx-status-indicator', 'unavailable');
                updateElementText('netalertx-status', 'Nicht erreichbar');
            }
        } else {
            updateStatusIndicator('netalertx-status-indicator', 'unavailable');
            updateElementText('netalertx-status', 'Status unbekannt');
        }

        // Overall status
        if (allHealthy) {
            updateStatusIndicator('overall-status .status-indicator', 'healthy');
            updateElementText('overall-status .status-text', 'Alle Kernsysteme gesund');
        } else {
            updateStatusIndicator('overall-status .status-indicator', 'warning');
            updateElementText('overall-status .status-text', 'Probleme erkannt');
        }

        // Auto-refresh every 30 seconds
        setTimeout(fetchData, 30000);
    }

    function formatUptime(seconds) {
        if (seconds === undefined || seconds === null) return '-';
        const d = Math.floor(seconds / (3600*24));
        const h = Math.floor(seconds % (3600*24) / 3600);
        const m = Math.floor(seconds % 3600 / 60);

        let res = [];
        if (d > 0) res.push(`${d}d`);
        if (h > 0) res.push(`${h}h`);
        res.push(`${m}m`);
        return res.join(' ');
    }
});
