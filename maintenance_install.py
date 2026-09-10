"""Installation-only provisioning; never exposed by sudoers or the HTTP API."""

import argparse
import fcntl
import ipaddress
import json
import os
import subprocess
import tarfile
import tempfile
from pathlib import Path

from maintenance_config import caddy_config, configuration


def atomic_file(path: Path, value: str) -> None:
    if path.is_symlink() or any(parent.is_symlink() for parent in path.parents):
        raise ValueError('Unsafe installation path')
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w') as handle:
            os.fchmod(handle.fileno(), 0o644)
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def detect_network() -> tuple[str, str]:
    routes = json.loads(subprocess.check_output(['/usr/sbin/ip', '-j', '-4', 'route', 'show', 'default'], text=True))
    if not routes:
        raise ValueError('No default interface; specify --hosts and --lan-cidr')
    addresses = json.loads(subprocess.check_output(['/usr/sbin/ip', '-j', '-4', 'addr', 'show', 'dev', routes[0]['dev']], text=True))
    for interface in addresses:
        for address in interface.get('addr_info', []):
            if address.get('scope') == 'global':
                network = ipaddress.ip_interface(f"{address['local']}/{address['prefixlen']}").network
                return f"pi.hole,{address['local']}", str(network)
    raise ValueError('LAN detection failed; specify --hosts and --lan-cidr')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--destdir', default='')
    parser.add_argument('--hosts', default='')
    parser.add_argument('--lan-cidr', default='')
    parser.add_argument('--lock-fd', type=int)
    args = parser.parse_args()
    if not args.destdir and os.geteuid() != 0:
        raise ValueError('Root required')
    root = Path(args.destdir or '/')
    config_path = root / 'etc/pihole-suite/maintenance-web.json'
    if not args.hosts and not args.lan_cidr and config_path.exists():
        raw = json.loads(config_path.read_text())
        hosts, cidr = ','.join(raw['hosts']), raw['lan_cidr']
    else:
        detected_hosts, detected_cidr = detect_network() if not (args.hosts and args.lan_cidr) else ('', '')
        hosts, cidr = args.hosts or detected_hosts, args.lan_cidr or detected_cidr
    config = configuration(hosts, cidr)
    atomic_file(config_path, json.dumps(config) + '\n')
    atomic_file(root / 'etc/caddy/Caddyfile.d/pihole-maintenance.caddy', caddy_config(config))
    if not args.destdir:
        from maintenance_backups import refresh_exports
        from maintenance_runner import RunnerContext
        context = RunnerContext()
        descriptor = os.dup(args.lock_fd) if args.lock_fd is not None else os.open(context.lock_file, os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        if os.fstat(descriptor).st_ino != context.lock_file.stat().st_ino:
            os.close(descriptor)
            raise ValueError('Invalid inherited maintenance lock')
        with os.fdopen(descriptor, 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            refresh_exports(context)
    print('Wartungsadresse / Maintenance URL: ' + config['allowed_origins'][0] + '/')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, tarfile.TarError, EOFError):
        raise SystemExit('Provisioning failed: check LAN configuration and maintenance lock') from None
