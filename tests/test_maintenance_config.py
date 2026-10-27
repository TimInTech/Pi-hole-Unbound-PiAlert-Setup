import pytest
def test_staging_output_does_not_write_files(tmp_path):
    import json
    import subprocess
    import sys
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / 'maintenance_install.py'
    result = subprocess.run([sys.executable, str(script), '--print-config', '--hosts', 'pi.hole,192.168.178.2', '--lan-cidr', '192.168.178.0/24'], cwd=tmp_path, check=True, capture_output=True, text=True)
    assert json.loads(result.stdout)['lan_cidr'] == '192.168.178.0/24'
    assert list(tmp_path.iterdir()) == []

from maintenance_config import caddy_config, configuration


def test_network_config_and_route_boundary():
    config = configuration('pi.hole,192.168.178.2', '192.168.178.0/24')
    assert config['allowed_origins'] == ['https://pi.hole:8443', 'https://192.168.178.2:8443']
    caddy = caddy_config(config)
    assert 'path / /maintenance.css /maintenance.js /api/session /api/session/logout /api/maintenance/*' in caddy
    assert 'respond "Not found" 404' in caddy
    assert 'max_size 8KB' in caddy
    assert '/dns' not in caddy


@pytest.mark.parametrize('host,network', [('host {', '192.168.1.0/24'), ('https://pi.hole', '192.168.1.0/24'), ('pi.hole', '0.0.0.0/0'), ('pi.hole', '8.8.8.0/24')])
def test_invalid_or_public_network_rejected(host, network):
    with pytest.raises(ValueError):
        configuration(host, network)
