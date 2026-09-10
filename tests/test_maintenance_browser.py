from pathlib import Path

import pytest

playwright = pytest.importorskip('playwright.sync_api')
ROOT = Path(__file__).resolve().parents[1]


def test_browser_states_languages_security_and_layout(tmp_path):
    from test_maintenance_web import state_payload
    job = state_payload()
    job['result']['system']['host'] = '<img src=x onerror=alert(1)>'
    authenticated = False
    requests = []
    errors = []
    with playwright.sync_playwright() as runtime:
        browser = runtime.chromium.launch(headless=True)
        page = browser.new_page(locale='de-DE')
        page.on('pageerror', lambda error: errors.append(str(error)))

        def route_request(route):
            nonlocal authenticated
            path = route.request.url.removeprefix('https://pi.hole:8443')
            method = route.request.method
            requests.append((method, path))
            assets = {'/': ('maintenance.html', 'text/html'), '/maintenance.css': ('maintenance.css', 'text/css'), '/maintenance.js': ('maintenance.js', 'text/javascript')}
            if path in assets:
                name, mime = assets[path]
                route.fulfill(body=(ROOT / 'web' / name).read_text(), content_type=mime)
            elif path == '/api/session':
                if method == 'POST':
                    authenticated = route.request.post_data_json.get('password') == 'browser-test-password'
                route.fulfill(status=200 if authenticated else 401, json={'csrf_token': 'test-only', 'pihole_url': 'http://pi.hole/admin/'})
            elif path == '/api/session/logout':
                authenticated = False
                route.fulfill(status=204)
            elif not authenticated:
                route.fulfill(status=401, json={})
            elif path == '/api/maintenance/status':
                route.fulfill(json=job)
            elif path == '/api/maintenance/backups':
                route.fulfill(json=[])
            elif method == 'POST':
                route.fulfill(status=202, json={'state': 'accepted'})
            else:
                route.fulfill(status=404)

        page.route('https://pi.hole:8443/**', route_request)
        page.goto('https://pi.hole:8443/')
        page.wait_for_load_state('networkidle')
        page.fill('#password', 'incorrect-password')
        page.click('#login-button')
        page.wait_for_function("document.querySelector('#login-error').textContent.includes('fehlgeschlagen')")
        assert page.locator('#login-error').is_visible()
        page.fill('#password', 'browser-test-password')
        page.click('#login-button')
        page.wait_for_function("document.querySelector('#status').textContent === 'Auftrag erfolgreich'")
        assert page.locator('#system-metrics').inner_text().find('<img src=x onerror=alert(1)>') >= 0
        assert page.locator('#system-metrics img').count() == 0
        assert not page.locator('details').evaluate('(node) => node.open')
        assert page.locator('#backup-button').is_disabled()
        assert page.locator('#update-button').is_disabled()
        page.check('#backup-confirmed')
        assert page.locator('#backup-button').is_enabled()
        page.fill('#update-confirmation', 'update')
        assert page.locator('#update-button').is_disabled()
        page.fill('#update-confirmation', 'UPDATE')
        assert page.locator('#update-button').is_enabled()
        page.select_option('#language', 'en')
        assert page.locator('#check-button').inner_text() == 'Run system check'
        assert page.evaluate('Object.keys(localStorage)') == ['maintenance-language']
        page.reload()
        page.wait_for_function("document.querySelector('#status').textContent === 'Job succeeded'")
        assert page.locator('#dashboard').is_visible()
        assert page.locator('#language').input_value() == 'en'
        page.select_option('#language', 'de')
        assert page.locator('#check-button').inner_text() == 'Systemcheck starten'
        for state in ['idle', 'running', 'failed', 'succeeded']:
            page.evaluate('(state) => { lastJob = {...lastJob, state}; renderJob(lastJob); }', state)
            assert page.locator('#status').get_attribute('data-state') == state
        page.evaluate('lastJob = {state: "succeeded", result: {}, steps: [{name:"future_code", ok:false, required:false, detail:"unknown"}]}; renderJob(lastJob)')
        assert 'Optionale Warnung' in page.locator('#step-list').inner_text()
        assert 'future code' in page.locator('#step-list').inner_text()
        page.click('#refresh-button')
        page.wait_for_load_state('networkidle')
        screenshots = Path('/tmp/pihole-maintenance-review')
        screenshots.mkdir(exist_ok=True)
        for width in [1440, 1063, 390, 320]:
            page.set_viewport_size({'width': width, 'height': 1000})
            assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), width
            page.screenshot(path=str(screenshots / f'dashboard-{width}.png'), full_page=True)
        page.set_viewport_size({'width': 1063, 'height': 1000})
        page.evaluate('document.body.style.zoom = "2"')
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
        page.evaluate('document.body.style.zoom = "1"')
        page.emulate_media(reduced_motion='reduce')
        assert page.locator('#check-button').evaluate('(node) => getComputedStyle(node).transitionDuration') == '0s'
        page.locator('#refresh-button').focus()
        page.keyboard.press('Tab')
        assert page.evaluate('document.activeElement.id') == 'check-button'
        assert page.locator('#check-button').evaluate('(node) => getComputedStyle(node).outlineStyle') != 'none'
        page.click('#check-button')
        assert page.locator('#backup-button').is_disabled()
        assert page.locator('#update-button').is_disabled()
        assert page.locator('#status').inner_text() == 'Auftrag wird gestartet'
        job['state'] = 'running'
        job['job_id'] += 'new'
        page.wait_for_function("document.querySelector('#status').textContent === 'Wartung läuft'")
        job['state'] = 'succeeded'
        page.wait_for_function("document.querySelector('#status').textContent === 'Auftrag erfolgreich'")
        page.wait_for_load_state('networkidle')
        status_count = requests.count(('GET', '/api/maintenance/status'))
        page.wait_for_timeout(2200)
        assert requests.count(('GET', '/api/maintenance/status')) == status_count
        authenticated = False
        page.click('#refresh-button')
        page.wait_for_function("document.activeElement.id === 'password'")
        assert 'Sitzung abgelaufen' in page.locator('#login-error').inner_text()
        assert not errors
        browser.close()
