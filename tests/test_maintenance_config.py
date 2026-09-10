import pytest

from maintenance_config import caddy_config, configuration


def test_network_config_and_route_boundary():
    config = configuration('pi.hole,192.168.178.2', '192.168.178.0/24')
    assert config['allowed_origins'] == ['https://pi.hole:8443', 'https://192.168.178.2:8443']
    caddy = caddy_config(config)
    assert 'path / /maintenance.css /maintenance.js /api/session /api/session/logout /api/maintenance/*' in caddy
    assert 'respond "Not found" 404' in caddy
    assert '/dns' not in caddy


@pytest.mark.parametrize('host,network', [('host {', '192.168.1.0/24'), ('https://pi.hole', '192.168.1.0/24'), ('pi.hole', '0.0.0.0/0'), ('pi.hole', '8.8.8.0/24')])
def test_invalid_or_public_network_rejected(host, network):
    with pytest.raises(ValueError):
        configuration(host, network)
