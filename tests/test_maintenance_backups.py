import hashlib
import json
import tarfile

import pytest
from test_maintenance_runner import held_lock, make_context

from maintenance_backups import delete_backup, read_index, refresh_exports
from maintenance_runner import run_job


def test_export_index_and_confirmed_deletion(tmp_path):
    context, _ = make_context(tmp_path)
    result = run_job('backup', context)
    assert result['state'] == 'succeeded'
    entries = read_index(context.export_root)
    assert len(entries) == 1
    entry = entries[0]
    archive = context.export_root / (entry['backup_id'] + '.tar.gz')
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == entry['sha256']
    with tarfile.open(archive) as handle:
        assert 'manifest.json' in handle.getnames()
        assert 'pihole/pihole.toml' in handle.getnames()
    assert archive.stat().st_mode & 0o777 == 0o640
    refresh_exports(context)
    assert read_index(context.export_root) == entries
    with held_lock(context.lock_file), pytest.raises(BlockingIOError):
        delete_backup(context, entry['backup_id'])
    delete_backup(context, entry['backup_id'])
    assert read_index(context.export_root) == []
    assert not archive.exists()


@pytest.mark.parametrize('bad_id', ['../outside', '.', 'anything', 'a/b'])
def test_delete_rejects_paths(tmp_path, bad_id):
    context, _ = make_context(tmp_path)
    with pytest.raises(ValueError):
        delete_backup(context, bad_id)


def test_manipulated_manifest_is_not_deleted(tmp_path):
    context, _ = make_context(tmp_path)
    result = run_job('backup', context)
    entry = read_index(context.export_root)[0]
    from pathlib import Path
    backup = Path(result['result']['backup_path'])
    manifest = json.loads((backup / 'manifest.json').read_text())
    manifest['job_id'] = 'different'
    (backup / 'manifest.json').write_text(json.dumps(manifest))
    with pytest.raises(ValueError):
        delete_backup(context, entry['backup_id'])
    assert backup.exists()


def test_symlink_manifest_and_failed_index_publish_preserve_backup(tmp_path, monkeypatch):
    from pathlib import Path

    import maintenance_backups
    context, _ = make_context(tmp_path)
    result = run_job('backup', context)
    entry = read_index(context.export_root)[0]
    backup = Path(result['result']['backup_path'])
    manifest = backup / 'manifest.json'
    external = tmp_path / 'external-manifest.json'
    manifest.rename(external)
    manifest.symlink_to(external)
    with pytest.raises(ValueError):
        delete_backup(context, entry['backup_id'])
    manifest.unlink()
    external.rename(manifest)

    def fail_publish(*args):
        raise OSError('simulated publication failure')

    monkeypatch.setattr(maintenance_backups, '_publish_index', fail_publish)
    with pytest.raises(OSError):
        delete_backup(context, entry['backup_id'])
    assert backup.exists()
    assert read_index(context.export_root) == [entry]


def test_corrupt_export_never_republished(tmp_path):
    context, _ = make_context(tmp_path)
    run_job('backup', context)
    entry = read_index(context.export_root)[0]
    archive = context.export_root / (entry['backup_id'] + '.tar.gz')
    archive.write_bytes(b'corrupt archive')
    with pytest.raises((ValueError, tarfile.TarError)):
        refresh_exports(context)


def test_truncated_export_finishes_job_as_failed(tmp_path):
    context, _ = make_context(tmp_path)
    run_job('backup', context)
    entry = read_index(context.export_root)[0]
    archive = context.export_root / (entry['backup_id'] + '.tar.gz')
    archive.write_bytes(archive.read_bytes()[:100])
    result = run_job('backup', context)
    assert result['state'] == 'failed'
    assert json.loads((context.state_dir / 'current.json').read_text())['state'] == 'failed'


def test_interrupted_deletion_recovers_on_export_refresh(tmp_path, monkeypatch):
    import maintenance_backups
    context, _ = make_context(tmp_path)
    run_job('backup', context)
    entry = read_index(context.export_root)[0]
    original = maintenance_backups.shutil.rmtree

    def interrupt(path):
        (path / 'manifest.json').unlink()
        raise OSError('simulated interrupted cleanup')

    monkeypatch.setattr(maintenance_backups.shutil, 'rmtree', interrupt)
    with pytest.raises(OSError):
        delete_backup(context, entry['backup_id'])
    monkeypatch.setattr(maintenance_backups.shutil, 'rmtree', original)
    refresh_exports(context)
    assert not list(context.backup_root.glob('.delet*'))
    assert read_index(context.export_root) == []
