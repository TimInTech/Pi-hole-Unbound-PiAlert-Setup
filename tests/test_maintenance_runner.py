import sqlite3
import sys
from pathlib import Path
import fcntl
import hashlib
import json
import os
import shutil
import time
from contextlib import contextmanager

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from maintenance_runner import CommandResult, RunnerContext, run_job
import maintenance_runner


class RecordingExecutor:
    def __init__(self, *, fail_dns: bool = False, dns_output: str = "203.0.113.7\n", listener_output: str | None = None):
        self.calls: list[list[str]] = []
        self.fail_dns = fail_dns
        self.dns_output = dns_output
        self.listener_output = listener_output or "udp UNCONN 0 0 127.0.0.1:53 0.0.0.0:*\nudp UNCONN 0 0 127.0.0.1:5335 0.0.0.0:*\n"
        self.timeouts: list[int | None] = []
        self.private_output = ""

    def __call__(self, argv: list[str], timeout_seconds: int | None = None) -> CommandResult:
        self.calls.append(argv)
        self.timeouts.append(timeout_seconds)
        if self.fail_dns and argv[0] == "/usr/bin/dig":
            return CommandResult(returncode=1, stdout="", stderr=f"DNS unavailable {self.private_output}")
        if argv[0] == "/usr/bin/dig":
            return CommandResult(returncode=0, stdout=f"{self.dns_output}{self.private_output}", stderr=self.private_output)
        if argv == ["/usr/bin/ss", "-ltnu"]:
            return CommandResult(returncode=0, stdout=f"{self.listener_output}{self.private_output}", stderr=self.private_output)
        return CommandResult(returncode=0, stdout=f"ok\n{self.private_output}", stderr=self.private_output)


@contextmanager
def held_lock(lock_file: Path):
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    with lock_file.open("a+", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        yield


def published_backups(context: RunnerContext) -> list[Path]:
    return sorted(path for path in context.backup_root.iterdir() if not path.name.startswith(".staging-"))


def make_context(tmp_path: Path, *, corrupt_database: bool = False, fail_dns: bool = False):
    etc_root = tmp_path / "etc"
    pihole_dir = etc_root / "pihole"
    unbound_dir = etc_root / "unbound"
    pihole_dir.mkdir(parents=True)
    unbound_dir.mkdir()
    (pihole_dir / "pihole.toml").write_text("upstreams = [\"127.0.0.1#5335\"]\n")
    (unbound_dir / "unbound.conf").write_text("server:\n")

    for database_name in ("gravity.db", "pihole-FTL.db"):
        database_path = pihole_dir / database_name
        if corrupt_database:
            database_path.write_bytes(b"not a sqlite database")
        else:
            with sqlite3.connect(database_path) as connection:
                connection.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")

    commands = RecordingExecutor(fail_dns=fail_dns)
    context = RunnerContext(
        etc_root=etc_root,
        state_dir=tmp_path / "state" / "jobs",
        backup_root=tmp_path / "backups",
        lock_file=tmp_path / "lock" / "maintenance.lock",
        command_executor=commands,
        pihole_bin="/usr/local/bin/pihole",
        state_gid=os.getgid(),
    )
    return context, commands


def test_rejects_unknown_action_without_commands(tmp_path):
    context, commands = make_context(tmp_path)

    with pytest.raises(ValueError, match="unsupported action"):
        run_job("shell", context)

    assert commands.calls == []


def test_check_is_failed_when_a_required_dns_query_fails(tmp_path):
    context, _ = make_context(tmp_path, fail_dns=True)

    result = run_job("check", context)

    assert result["state"] == "failed"
    assert result["error"]["code"] == "check_failed"


def test_corrupt_sqlite_database_prevents_backup_publication(tmp_path):
    context, _ = make_context(tmp_path, corrupt_database=True)

    result = run_job("backup", context)

    assert result["state"] == "failed"
    assert list(context.backup_root.iterdir()) == []


def test_update_stops_before_apt_when_backup_fails(tmp_path):
    context, commands = make_context(tmp_path, corrupt_database=True)

    result = run_job("update", context)

    assert result["state"] == "failed"
    assert ["/usr/bin/apt-get", "update"] not in commands.calls


def test_second_job_reports_busy(tmp_path):
    context, _ = make_context(tmp_path)

    with held_lock(context.lock_file):
        result = run_job("check", context)

    assert result["error"]["code"] == "busy"


def test_command_execution_observes_running_state_before_terminal_state(tmp_path):
    context, commands = make_context(tmp_path)
    observed_states: list[str] = []
    original_call = commands.__call__

    def observe_state(argv: list[str], timeout_seconds: int | None = None) -> CommandResult:
        observed_states.append(json.loads((context.state_dir / "current.json").read_text())["state"])
        return original_call(argv, timeout_seconds)

    commands.__call__ = observe_state
    context = RunnerContext(
        etc_root=context.etc_root,
        state_dir=context.state_dir,
        backup_root=context.backup_root,
        lock_file=context.lock_file,
        command_executor=commands.__call__,
        pihole_bin=context.pihole_bin,
        state_gid=context.state_gid,
    )

    result = run_job("check", context)

    assert observed_states == ["running"] * len(commands.calls)
    assert result["state"] == "succeeded"
    assert json.loads((context.state_dir / "current.json").read_text())["state"] == "succeeded"


def test_state_files_have_mode_0640(tmp_path):
    context, _ = make_context(tmp_path)

    result = run_job("check", context)

    assert os.stat(context.state_dir / "current.json").st_mode & 0o777 == 0o640
    assert os.stat(context.state_dir / f"{result['job_id']}.json").st_mode & 0o777 == 0o640


def test_published_backup_directory_has_mode_0700(tmp_path):
    context, _ = make_context(tmp_path)

    result = run_job("backup", context)

    assert result["state"] == "succeeded"
    assert os.stat(result["result"]["backup_path"]).st_mode & 0o777 == 0o700


def test_failed_backup_removes_its_staging_directory(tmp_path):
    context, _ = make_context(tmp_path, corrupt_database=True)

    run_job("backup", context)

    assert not list(context.backup_root.glob(".staging-*"))


def test_backup_retention_keeps_only_the_ten_newest_verified_backups(tmp_path):
    context, _ = make_context(tmp_path)

    for _ in range(11):
        assert run_job("backup", context)["state"] == "succeeded"

    assert len(published_backups(context)) == 10


def test_backup_manifest_hashes_match_each_published_file(tmp_path):
    context, _ = make_context(tmp_path)

    result = run_job("backup", context)

    backup = Path(result["result"]["backup_path"])
    manifest = json.loads((backup / "manifest.json").read_text())
    assert manifest["files"]
    for entry in manifest["files"]:
        file_path = backup / entry["path"]
        assert entry["sha256"] == hashlib.sha256(file_path.read_bytes()).hexdigest()
        assert entry["size"] == file_path.stat().st_size


def test_backup_copies_configuration_without_following_symlinks(tmp_path):
    context, _ = make_context(tmp_path)
    outside_file = tmp_path / "outside.conf"
    outside_file.write_text("must never be copied")
    (context.etc_root / "unbound" / "outside-link.conf").symlink_to(outside_file)

    result = run_job("backup", context)

    backup = Path(result["result"]["backup_path"])
    assert (backup / "pihole" / "pihole.toml").read_text() == 'upstreams = ["127.0.0.1#5335"]\n'
    assert (backup / "unbound" / "unbound.conf").read_text() == "server:\n"
    assert not (backup / "unbound" / "outside-link.conf").exists()


def test_update_command_order(tmp_path):
    context, commands = make_context(tmp_path)

    assert run_job("update", context)["state"] == "succeeded"

    assert [call for call in commands.calls if call in (
        ["/usr/bin/apt-get", "update"],
        ["/usr/bin/apt-get", "-y", "upgrade"],
        [context.pihole_bin, "-up"],
        [context.pihole_bin, "-g"],
    )] == [
        ["/usr/bin/apt-get", "update"],
        ["/usr/bin/apt-get", "-y", "upgrade"],
        [context.pihole_bin, "-up"],
        [context.pihole_bin, "-g"],
    ]


def test_check_fails_when_dns_returns_no_answers(tmp_path):
    context, commands = make_context(tmp_path)
    commands.dns_output = ""

    result = run_job("check", context)

    assert result["state"] == "failed"
    assert result["error"]["code"] == "check_failed"


def test_check_fails_when_a_required_listener_is_missing(tmp_path):
    context, commands = make_context(tmp_path)
    commands.listener_output = "udp UNCONN 0 0 127.0.0.1:53 0.0.0.0:*\n"

    result = run_job("check", context)

    assert result["state"] == "failed"
    assert result["error"]["code"] == "check_failed"


def test_symlinked_state_directory_is_rejected_before_commands_run(tmp_path):
    context, commands = make_context(tmp_path)
    state_target = tmp_path / "state-target"
    state_target.mkdir()
    context.state_dir.parent.mkdir(parents=True)
    context.state_dir.symlink_to(state_target, target_is_directory=True)

    with pytest.raises(RuntimeError, match="state directory must not be a symlink"):
        run_job("check", context)

    assert commands.calls == []


def test_symlinked_backup_root_is_rejected_without_publication(tmp_path):
    context, _ = make_context(tmp_path)
    backup_target = tmp_path / "backup-target"
    backup_target.mkdir()
    context.backup_root.symlink_to(backup_target, target_is_directory=True)

    result = run_job("backup", context)

    assert result["state"] == "failed"
    assert result["error"]["code"] == "backup_failed"
    assert not list(backup_target.iterdir())


def test_check_result_contains_safe_system_summary(tmp_path):
    context, _ = make_context(tmp_path)

    result = run_job("check", context)

    assert result["result"]["system"].keys() >= {"host", "kernel", "architecture", "uptime_seconds", "root_filesystem"}
    assert "example.com" not in json.dumps(result)


def test_update_reports_reboot_requirement_without_rebooting(tmp_path):
    context, commands = make_context(tmp_path)
    reboot_marker = tmp_path / "reboot-required"
    reboot_marker.touch()
    context = RunnerContext(
        etc_root=context.etc_root,
        state_dir=context.state_dir,
        backup_root=context.backup_root,
        lock_file=context.lock_file,
        command_executor=commands,
        pihole_bin=context.pihole_bin,
        state_gid=context.state_gid,
        reboot_required_path=reboot_marker,
    )

    result = run_job("update", context)

    assert result["state"] == "succeeded"
    assert result["result"]["reboot_required"] is True
    assert not any("reboot" in call for call in commands.calls)


def test_check_collects_unbound_version_with_a_fixed_command(tmp_path):
    context, commands = make_context(tmp_path)

    assert run_job("check", context)["state"] == "succeeded"

    assert ["/usr/sbin/unbound", "-V"] in commands.calls


@pytest.mark.parametrize("relative_path", ("pihole/pihole.toml", "unbound"))
def test_backup_fails_when_required_configuration_is_missing(tmp_path, relative_path):
    context, _ = make_context(tmp_path)
    required_path = context.etc_root / relative_path
    if required_path.is_dir():
        shutil.rmtree(required_path)
    else:
        required_path.unlink()

    result = run_job("backup", context)

    assert result["state"] == "failed"
    assert result["error"]["code"] == "backup_failed"
    assert not published_backups(context)


def test_job_state_persists_only_allowlisted_structured_command_results(tmp_path):
    context, commands = make_context(tmp_path)
    commands.private_output = "private-zone.example --token=never-persist"

    result = run_job("check", context)

    persisted = (context.state_dir / "current.json").read_text()
    assert commands.private_output not in json.dumps(result)
    assert commands.private_output not in persisted
    for step in result["steps"]:
        assert set(step) <= {"name", "required", "ok", "detail"}


def test_update_uses_long_timeouts_while_final_check_uses_short_timeouts(tmp_path):
    context, commands = make_context(tmp_path)

    assert run_job("update", context)["state"] == "succeeded"

    timeouts_by_command = dict(zip((tuple(call) for call in commands.calls), commands.timeouts, strict=True))
    assert timeouts_by_command[("/usr/bin/apt-get", "update")] == 7200
    assert timeouts_by_command[("/usr/bin/apt-get", "-y", "upgrade")] == 7200
    assert timeouts_by_command[(context.pihole_bin, "-up")] == 7200
    assert timeouts_by_command[("/usr/bin/dig", "+short", "@127.0.0.1", "example.com", "+time=3", "+tries=1")] == 30


def test_timed_out_command_terminates_its_entire_process_group(tmp_path, monkeypatch):
    child_pid_path = tmp_path / "child.pid"
    child_code = "import signal, time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(60)"
    parent_code = (
        "from pathlib import Path; import subprocess, sys, time; "
        f"child = subprocess.Popen([sys.executable, '-c', {child_code!r}], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); "
        f"Path({str(child_pid_path)!r}).write_text(str(child.pid)); time.sleep(60)"
    )
    monkeypatch.setattr(maintenance_runner, "PROCESS_TERMINATION_GRACE_SECONDS", 0.05)

    try:
        result = maintenance_runner._run_command([sys.executable, "-c", parent_code], timeout_seconds=0.1)
    except TypeError:
        pytest.fail("runner does not support a bounded command timeout")

    child_pid = int(child_pid_path.read_text())
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        try:
            os.kill(child_pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.05)
    else:
        pytest.fail("child process survived command timeout")
    assert result.returncode != 0


def manifest_entry(path: Path, relative_path: str) -> dict[str, object]:
    return {
        "path": relative_path,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size": path.stat().st_size,
    }


def test_manifest_rejects_empty_or_incomplete_file_coverage(tmp_path):
    staging = tmp_path / "staging"
    pihole_toml = staging / "pihole" / "pihole.toml"
    unbound_conf = staging / "unbound" / "unbound.conf"
    pihole_toml.parent.mkdir(parents=True)
    unbound_conf.parent.mkdir()
    pihole_toml.write_text("config")
    unbound_conf.write_text("server:")
    base = {"schema_version": 1, "job_id": "job", "created_at": "2026-01-01T00:00:00Z", "host": "host", "versions": {"runner": "1"}}

    for files in ([], [manifest_entry(pihole_toml, "pihole/pihole.toml")]):
        (staging / "manifest.json").write_text(json.dumps({**base, "files": files}))
        with pytest.raises(RuntimeError, match="manifest"):
            maintenance_runner._verify_manifest(staging)


@pytest.mark.parametrize("unsafe_kind", ("absolute", "traversal"))
def test_manifest_rejects_absolute_and_traversal_paths(tmp_path, unsafe_kind):
    staging = tmp_path / "staging"
    staging.mkdir()
    external = tmp_path / "external"
    external.write_text("external file")
    unsafe_path = str(external) if unsafe_kind == "absolute" else "../external"
    manifest = {
        "schema_version": 1,
        "job_id": "job",
        "created_at": "2026-01-01T00:00:00Z",
        "host": "host",
        "versions": {"runner": "1"},
        "files": [manifest_entry(external, unsafe_path)],
    }
    (staging / "manifest.json").write_text(json.dumps(manifest))

    with pytest.raises(RuntimeError, match="manifest"):
        maintenance_runner._verify_manifest(staging)


def test_manifest_accepts_a_covered_nested_file_named_manifest_json(tmp_path):
    staging = tmp_path / "staging"
    pihole_toml = staging / "pihole" / "pihole.toml"
    nested_manifest = staging / "unbound" / "manifest.json"
    pihole_toml.parent.mkdir(parents=True)
    nested_manifest.parent.mkdir()
    pihole_toml.write_text("config")
    nested_manifest.write_text("nested config")
    manifest = {
        "schema_version": 1,
        "job_id": "job",
        "created_at": "2026-01-01T00:00:00Z",
        "host": "host",
        "versions": {"runner": "1"},
        "files": [
            manifest_entry(pihole_toml, "pihole/pihole.toml"),
            manifest_entry(nested_manifest, "unbound/manifest.json"),
        ],
    }
    (staging / "manifest.json").write_text(json.dumps(manifest))

    maintenance_runner._verify_manifest(staging)
