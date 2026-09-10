#!/usr/bin/env python3
"""Verified read-only exports and a narrowly scoped privileged deletion command."""

import datetime as dt
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import tarfile
import tempfile
from pathlib import Path

EXPORT_ROOT = Path('/var/lib/pihole-suite/exports')
BACKUP_ID = re.compile(r'\d{8}T\d{6}Z-\d{8}T\d{12}Z-[a-f0-9]{32}')


def valid_id(value: str) -> bool:
    return isinstance(value, str) and BACKUP_ID.fullmatch(value) is not None


def safe_file(path: Path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    metadata = os.fstat(descriptor)
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        os.close(descriptor)
        raise ValueError('Unsafe file')
    return os.fdopen(descriptor, 'rb')


def read_index(root: Path) -> list[dict]:
    try:
        with safe_file(root / 'index.json') as handle:
            raw = handle.read(32769)
        if len(raw) > 32768:
            raise ValueError('Invalid index')
        entries = json.loads(raw)
    except FileNotFoundError:
        return []
    if not isinstance(entries, list) or len(entries) > 10:
        raise ValueError('Invalid index')
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {'backup_id', 'created_at', 'size', 'sha256', 'verified'}:
            raise ValueError('Invalid index')
        if not valid_id(entry['backup_id']) or entry['backup_id'] in seen or entry['verified'] is not True:
            raise ValueError('Invalid index')
        seen.add(entry['backup_id'])
        if not isinstance(entry['size'], int) or isinstance(entry['size'], bool) or entry['size'] < 1:
            raise ValueError('Invalid index')
        if not isinstance(entry['sha256'], str) or not re.fullmatch('[a-f0-9]{64}', entry['sha256']):
            raise ValueError('Invalid index')
        if not isinstance(entry['created_at'], str) or len(entry['created_at']) > 40:
            raise ValueError('Invalid index')
        dt.datetime.fromisoformat(entry['created_at'])
    return entries


def _verified_backup(context, backup_id: str) -> Path:
    from maintenance_runner import _verify_manifest
    if not valid_id(backup_id):
        raise ValueError('Invalid backup ID')
    candidate = context.backup_root / backup_id
    if any(parent.is_symlink() for parent in candidate.parents) or candidate.is_symlink() or not candidate.is_dir():
        raise FileNotFoundError('Backup not found')
    if any(path.is_symlink() or (path.is_file() and path.stat().st_nlink != 1) for path in candidate.rglob('*')):
        raise ValueError('Unsafe backup')
    try:
        _verify_manifest(candidate)
        manifest = json.loads((candidate / 'manifest.json').read_text())
        if backup_id.split('-', 1)[1] != manifest['job_id']:
            raise ValueError('Backup ID mismatch')
        dt.datetime.fromisoformat(manifest['created_at'])
    except RuntimeError as error:
        raise ValueError('Invalid backup') from error
    return candidate


def _publish_index(context, entries):
    from maintenance_runner import _atomic_json_write
    _atomic_json_write(context.export_root / 'index.json', entries, context)


def refresh_exports(context) -> None:
    import grp

    from maintenance_runner import _prepare_directory, _sha256
    recover_deletions(context)
    _prepare_directory(context.export_root, 0o750, 'export directory')
    gid = context.state_gid if context.state_gid is not None else grp.getgrnam('pihole-suite').gr_gid
    os.chown(context.export_root, -1, gid)
    entries = []
    for candidate in sorted(context.backup_root.iterdir(), reverse=True):
        if not valid_id(candidate.name) or len(entries) >= 10:
            continue
        try:
            backup = _verified_backup(context, candidate.name)
        except (OSError, ValueError):
            continue
        archive = context.export_root / (candidate.name + '.tar.gz')
        if archive.is_symlink():
            raise ValueError('Unsafe export')
        if not archive.exists():
            descriptor, temporary = tempfile.mkstemp(prefix='.export-', dir=context.export_root)
            try:
                with os.fdopen(descriptor, 'wb') as output:
                    with tarfile.open(fileobj=output, mode='w:gz') as bundle:
                        for path in sorted(backup.rglob('*')):
                            bundle.add(path, arcname=path.relative_to(backup).as_posix(), recursive=False)
                    output.flush()
                    os.fsync(output.fileno())
                    os.fchown(output.fileno(), -1, gid)
                    os.fchmod(output.fileno(), 0o640)
                os.replace(temporary, archive)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
        manifest = json.loads((backup / 'manifest.json').read_text())
        with safe_file(archive) as handle, tarfile.open(fileobj=handle, mode='r:gz') as bundle:
            expected = {item['path']: item for item in manifest['files']}
            directories = {path.relative_to(backup).as_posix() for path in backup.rglob('*') if path.is_dir()}
            covered = set()
            seen_members = set()
            for member in bundle:
                if member.name in seen_members:
                    raise ValueError('Duplicate export member')
                seen_members.add(member.name)
                if member.isdir():
                    if member.name not in directories:
                        raise ValueError('Unsafe export directory')
                    continue
                if not member.isfile() or member.name in covered:
                    raise ValueError('Unsafe export content')
                covered.add(member.name)
                source = bundle.extractfile(member)
                if member.name == 'manifest.json':
                    if source.read() != (backup / 'manifest.json').read_bytes():
                        raise ValueError('Export manifest mismatch')
                elif member.name not in expected or member.size != expected[member.name]['size'] or hashlib.file_digest(source, 'sha256').hexdigest() != expected[member.name]['sha256']:
                    raise ValueError('Export verification failed')
            if covered != set(expected) | {'manifest.json'}:
                raise ValueError('Incomplete export')
        entries.append({'backup_id': candidate.name, 'created_at': manifest['created_at'], 'size': archive.stat().st_size, 'sha256': _sha256(archive), 'verified': True})
    _publish_index(context, entries)
    retained = {entry['backup_id'] + '.tar.gz' for entry in entries}
    for archive in context.export_root.glob('*.tar.gz'):
        if valid_id(archive.name.removesuffix('.tar.gz')) and archive.name not in retained:
            archive.unlink()


def delete_backup(context, backup_id: str) -> None:
    if not valid_id(backup_id):
        raise ValueError('Invalid backup ID')
    with os.fdopen(os.open(context.lock_file, os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600), 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        recover_deletions(context)
        backup = _verified_backup(context, backup_id)
        archive = context.export_root / (backup_id + '.tar.gz')
        if archive.is_symlink():
            raise ValueError('Unsafe export')
        entries = read_index(context.export_root)
        tombstone = backup.with_name('.deleting-' + backup_id)
        if tombstone.exists() or tombstone.is_symlink():
            raise ValueError('Unfinished deletion')
        from maintenance_runner import _atomic_json_write, _sync_directory
        marker = context.backup_root / ('.delete-' + backup_id + '.json')
        intent = {'backup_id': backup_id, 'job_id': backup_id.split('-', 1)[1], 'committed': False}
        _atomic_json_write(marker, intent, context)
        os.replace(backup, tombstone)
        _sync_directory(context.backup_root)
        try:
            _publish_index(context, [entry for entry in entries if entry['backup_id'] != backup_id])
        except Exception:
            os.replace(tombstone, backup)
            marker.unlink()
            _sync_directory(context.backup_root)
            raise
        _atomic_json_write(marker, {**intent, 'committed': True}, context)
        archive.unlink(missing_ok=True)
        shutil.rmtree(tombstone)
        marker.unlink()
        _sync_directory(context.backup_root)


def recover_deletions(context) -> None:
    from maintenance_runner import _sync_directory

    for marker in context.backup_root.glob('.delete-*.json'):
        backup_id = marker.name.removeprefix('.delete-').removesuffix('.json')
        if not valid_id(backup_id):
            raise ValueError('Invalid deletion marker')
        with safe_file(marker) as handle:
            intent = json.loads(handle.read(1025))
        if not isinstance(intent, dict) or set(intent) != {'backup_id', 'job_id', 'committed'} or intent['backup_id'] != backup_id or intent['job_id'] != backup_id.split('-', 1)[1] or not isinstance(intent['committed'], bool):
            raise ValueError('Invalid deletion intent')
        tombstone = context.backup_root / ('.deleting-' + backup_id)
        backup = context.backup_root / backup_id
        if tombstone.is_symlink() or backup.is_symlink() or any(path.is_symlink() for path in tombstone.rglob('*')):
            raise ValueError('Unsafe interrupted deletion')
        if intent['committed']:
            (context.export_root / (backup_id + '.tar.gz')).unlink(missing_ok=True)
            if tombstone.exists():
                shutil.rmtree(tombstone)
        elif tombstone.exists():
            if backup.exists():
                raise ValueError('Conflicting interrupted deletion')
            os.replace(tombstone, backup)
        marker.unlink()
        _sync_directory(context.backup_root)


def main() -> int:
    if os.geteuid() != 0 or len(sys.argv) != 3 or sys.argv[1] != 'delete' or not valid_id(sys.argv[2]):
        return 2
    from maintenance_runner import RunnerContext
    try:
        import grp
        os.setegid(grp.getgrnam('pihole-suite').gr_gid)
        delete_backup(RunnerContext(), sys.argv[2])
    except BlockingIOError:
        return 3
    except FileNotFoundError:
        return 4
    except (OSError, ValueError, KeyError):
        return 5
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
