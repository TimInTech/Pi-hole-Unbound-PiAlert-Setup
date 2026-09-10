"""Validated LAN configuration shared by Caddy and the browser API."""

import ipaddress
import re


def configuration(hosts: str, cidr: str) -> dict:
    selected = hosts.split(',')
    if not selected or len(selected) > 8 or len(set(selected)) != len(selected):
        raise ValueError('Invalid hosts')
    for host in selected:
        if len(host) > 253 or not all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', part) for part in host.split('.')):
            raise ValueError('Invalid host')
    network = ipaddress.ip_network(cidr, strict=True)
    private = [ipaddress.ip_network(value) for value in ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']]
    if network.version != 4 or not any(network.subnet_of(allowed) for allowed in private):
        raise ValueError('An RFC1918 LAN CIDR is required')
    return {'hosts': selected, 'lan_cidr': str(network), 'allowed_origins': [f'https://{host}:8443' for host in selected], 'pihole_url': f'http://{selected[0]}/admin/'}


def caddy_config(config: dict) -> str:
    hosts = ', '.join(host + ':8443' for host in config['hosts'])
    return f'''{hosts} {{
    tls internal
    @lan remote_ip {config['lan_cidr']} 127.0.0.1 ::1
    handle @lan {{
        @maintenance path / /maintenance.css /maintenance.js /api/session /api/session/logout /api/maintenance/*
        handle @maintenance {{
            reverse_proxy 127.0.0.1:8090
        }}
        respond "Not found" 404
    }}
    respond "Forbidden" 403
}}
'''
