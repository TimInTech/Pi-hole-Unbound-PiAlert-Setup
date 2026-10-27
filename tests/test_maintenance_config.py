import pytest
from maintenance_install import installation_target

def test_installation_target_rejects_traversal_and_symlinks(tmp_path):
    assert installation_target(tmp_path, 'etc/pihole-suite/maintenance-web.json') == tmp_path / 'etc/pihole-suite/maintenance-web.json'
    with pytest.raises(ValueError):
        installation_target(tmp_path, '../outside')
    (tmp_path / 'etc').symlink_to(tmp_path.parent, target_is_directory=True)
    with pytest.raises(ValueError):
        installation_target(tmp_path, 'etc/pihole-suite/maintenance-web.json')

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
