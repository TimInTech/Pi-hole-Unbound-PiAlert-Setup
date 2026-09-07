#!/usr/bin/env python3
"""Root-only runner for the fixed Pi-hole maintenance jobs."""

from __future__ import annotations

import datetime as dt
import enum
import fcntl
import grp
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import uuid
import platform
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Sequence


MAX_OUTPUT_LENGTH = 2_000
STATE_FILE_MODE = 0o640
BACKUP_DIR_MODE = 0o700
ALLOWED_ACTIONS = ("check", "backup", "update")


class Action(str, enum.Enum):
    CHECK = "check"
    BACKUP = "backup"
    UPDATE = "update"


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str = ""
    stderr: str = ""


CommandExecutor = Callable[[list[str]], CommandResult]


@dataclass(frozen=True)
class RunnerContext:
    etc_root: Path = Path("/etc")
    state_dir: Path = Path("/var/lib/pihole-suite/jobs")
    backup_root: Path = Path("/var/backups/pihole-suite")
    lock_file: Path = Path("/run/lock/pihole-maintenance-web.lock")
    command_executor: CommandExecutor | None = None
    pihole_bin: str = "/usr/local/bin/pihole"
    state_gid: int | None = None
    reboot_required_path: Path = Path("/var/run/reboot-required")

    def __post_init__(self) -> None:
        for field_name in ("etc_root", "state_dir", "backup_root", "lock_file", "reboot_required_path"):
            object.__setattr__(self, field_name, Path(getattr(self, field_name)))
        if self.command_executor is None:
            object.__setattr__(self, "command_executor", _run_command)


def _run_command(argv: list[str]) -> CommandResult:
    environment = {"PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"}
    if argv == ["/usr/bin/apt-get", "-y", "upgrade"]:
        environment["DEBIAN_FRONTEND"] = "noninteractive"
    try:
        completed = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            timeout=300,
            env=environment,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return CommandResult(returncode=1, stderr=str(error))
    return CommandResult(completed.returncode, completed.stdout, completed.stderr)


def _sanitize_output(value: str) -> str:
    clean = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]", "", value)
    return clean[:MAX_OUTPUT_LENGTH]


def _utc_now() -> str:
    return dt.datetime.now(tz=dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _job_id() -> str:
    timestamp = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    return f"{timestamp}-{uuid.uuid4().hex}"


def _as_action(action: Action | str) -> Action:
    try:
        return Action(action)
    except ValueError as error:
        raise ValueError(f"unsupported action: {action}") from error


def _reject_symlink(path: Path, label: str) -> None:
    if path.is_symlink():
        raise RuntimeError(f"{label} must not be a symlink")


def _prepare_directory(path: Path, mode: int, label: str) -> None:
    _reject_symlink(path, label)
    path.mkdir(mode=mode, parents=True, exist_ok=True)
    _reject_symlink(path, label)
    if not path.is_dir():
        raise RuntimeError(f"{label} is not a directory")


def _atomic_json_write(path: Path, payload: dict[str, Any], context: RunnerContext) -> None:
    _prepare_directory(path.parent, 0o750, "state directory")
    descriptor, temporary_name = tempfile.mkstemp(prefix=".tmp-", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, sort_keys=True, separators=(",", ":"))
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, STATE_FILE_MODE)
        state_gid = context.state_gid
        if state_gid is None:
            state_gid = grp.getgrnam("pihole-suite").gr_gid
        os.chown(temporary_path, -1, state_gid)
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def _write_state(payload: dict[str, Any], context: RunnerContext, *, history: bool = False) -> None:
    _atomic_json_write(context.state_dir / "current.json", payload, context)
    if history:
        _atomic_json_write(context.state_dir / f"{payload['job_id']}.json", payload, context)


def _command_step(name: str, argv: list[str], context: RunnerContext, *, required: bool = True) -> dict[str, Any]:
    assert context.command_executor is not None
    result = context.command_executor(argv)
    return {
        "name": name,
        "required": required,
        "ok": result.returncode == 0,
        "output": _sanitize_output(result.stdout),
        "error_output": _sanitize_output(result.stderr),
    }


def _run_check(context: RunnerContext) -> tuple[list[dict[str, Any]], str | None]:
    steps = [
        _command_step("pihole_ftl", ["/usr/bin/systemctl", "is-active", "pihole-FTL"], context),
        _command_step("unbound", ["/usr/bin/systemctl", "is-active", "unbound"], context),
        _command_step("pihole_version", [context.pihole_bin, "-v"], context),
        _command_step("unbound_version", ["/usr/sbin/unbound", "-V"], context),
        _command_step("unbound_config", ["/usr/sbin/unbound-checkconf"], context),
        _command_step("listeners", ["/usr/bin/ss", "-ltnu"], context),
        _command_step(
            "dns_pihole",
            ["/usr/bin/dig", "+short", "@127.0.0.1", "example.com", "+time=3", "+tries=1"],
            context,
        ),
        _command_step(
            "dns_unbound",
            ["/usr/bin/dig", "+short", "-p", "5335", "@127.0.0.1", "example.com", "+time=3", "+tries=1"],
            context,
        ),
        _command_step("apt_simulation", ["/usr/bin/apt-get", "-s", "upgrade"], context),
    ]
    for step in steps:
        if step["name"] in {"dns_pihole", "dns_unbound"} and step["ok"] and not step["output"].strip():
            step["ok"] = False
            step["error_output"] = "DNS query returned no answer"
    listener_step = next(step for step in steps if step["name"] == "listeners")
    if listener_step["ok"] and not all(
        re.search(rf":{port}(?:\s|$)", listener_step["output"]) for port in (53, 5335)
    ):
        listener_step["ok"] = False
        listener_step["error_output"] = "required DNS listener is missing"
    if any(not step["ok"] and step["required"] for step in steps):
        return steps, "check_failed"
    return steps, None


def _sqlite_backup(source: Path, destination: Path) -> None:
    destination.parent.mkdir(mode=BACKUP_DIR_MODE, parents=True, exist_ok=True)
    with sqlite3.connect(source) as source_connection, sqlite3.connect(destination) as destination_connection:
        source_connection.backup(destination_connection)
        quick_check = destination_connection.execute("PRAGMA quick_check").fetchone()
    if quick_check != ("ok",):
        raise RuntimeError(f"SQLite quick_check failed for {source.name}")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _manifest(staging: Path, job_id: str) -> Path:
    entries = []
    for candidate in sorted(staging.rglob("*")):
        if candidate.is_file() and candidate.name != "manifest.json":
            entries.append({
                "path": candidate.relative_to(staging).as_posix(),
                "sha256": _sha256(candidate),
                "size": candidate.stat().st_size,
            })
    manifest_path = staging / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "job_id": job_id,
                "created_at": _utc_now(),
                "host": platform.node(),
                "versions": {"runner": "1", "python": platform.python_version()},
                "files": entries,
            },
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    return manifest_path


def _verify_manifest(staging: Path) -> None:
    manifest = json.loads((staging / "manifest.json").read_text(encoding="utf-8"))
    for entry in manifest["files"]:
        candidate = staging / entry["path"]
        if not candidate.is_file() or candidate.stat().st_size != entry["size"] or _sha256(candidate) != entry["sha256"]:
            raise RuntimeError(f"manifest verification failed for {entry['path']}")


def _copy_regular_file(source: Path, destination: Path) -> None:
    if source.is_symlink():
        return
    destination.parent.mkdir(mode=BACKUP_DIR_MODE, parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    os.chmod(destination, 0o600)


def _copy_directory_without_symlinks(source: Path, destination: Path) -> None:
    if source.is_symlink() or not source.is_dir():
        return
    for root, directories, files in os.walk(source, followlinks=False):
        root_path = Path(root)
        directories[:] = [name for name in directories if not (root_path / name).is_symlink()]
        relative_path = root_path.relative_to(source)
        target_directory = destination / relative_path
        target_directory.mkdir(mode=BACKUP_DIR_MODE, parents=True, exist_ok=True)
        os.chmod(target_directory, BACKUP_DIR_MODE)
        for name in files:
            _copy_regular_file(root_path / name, target_directory / name)


def _copy_configuration(context: RunnerContext, staging: Path) -> None:
    pihole_dir = context.etc_root / "pihole"
    pihole_toml = pihole_dir / "pihole.toml"
    unbound_dir = context.etc_root / "unbound"
    if not pihole_toml.is_file() or pihole_toml.is_symlink():
        raise RuntimeError("required Pi-hole configuration is missing or unsafe")
    if not unbound_dir.is_dir() or unbound_dir.is_symlink():
        raise RuntimeError("required Unbound configuration is missing or unsafe")
    for name in ("pihole.toml", "custom.list", "dhcp.leases", "setupVars.conf"):
        source = pihole_dir / name
        if source.exists() and not source.is_symlink():
            _copy_regular_file(source, staging / "pihole" / name)
    _copy_directory_without_symlinks(pihole_dir / "dnsmasq.d", staging / "pihole" / "dnsmasq.d")
    _copy_directory_without_symlinks(unbound_dir, staging / "unbound")
    systemd_dir = context.etc_root / "systemd" / "system"
    for name in ("pihole-FTL.service.d", "unbound.service.d"):
        _copy_directory_without_symlinks(systemd_dir / name, staging / "systemd" / name)


def _retain_newest_backups(backup_root: Path) -> None:
    verified_backups: list[Path] = []
    for candidate in backup_root.iterdir():
        if candidate.name.startswith(".staging-") or candidate.is_symlink() or not candidate.is_dir():
            continue
        try:
            _verify_manifest(candidate)
        except (OSError, ValueError, KeyError, TypeError, RuntimeError):
            continue
        verified_backups.append(candidate)
    for obsolete in sorted(verified_backups, key=lambda path: path.name, reverse=True)[10:]:
        shutil.rmtree(obsolete)


def _system_summary() -> dict[str, Any]:
    try:
        uptime_seconds = int(float(Path("/proc/uptime").read_text(encoding="utf-8").split()[0]))
    except (OSError, ValueError, IndexError):
        uptime_seconds = None
    try:
        memory_total = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES")
        memory_available = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_AVPHYS_PAGES")
    except (ValueError, OSError, AttributeError):
        memory_total = None
        memory_available = None
    filesystem = shutil.disk_usage("/")
    summary: dict[str, Any] = {
        "host": platform.node(),
        "operating_system": platform.platform(),
        "kernel": platform.release(),
        "architecture": platform.machine(),
        "uptime_seconds": uptime_seconds,
        "load_average": list(os.getloadavg()),
        "memory": {"total_bytes": memory_total, "available_bytes": memory_available},
        "root_filesystem": {"total_bytes": filesystem.total, "used_bytes": filesystem.used, "free_bytes": filesystem.free},
    }
    thermal_path = Path("/sys/class/thermal/thermal_zone0/temp")
    try:
        summary["temperature_celsius"] = int(thermal_path.read_text(encoding="utf-8").strip()) / 1000
    except (OSError, ValueError):
        summary["temperature_celsius"] = None
    return summary


def _run_backup(context: RunnerContext, job_id: str) -> tuple[list[dict[str, Any]], str | None, str | None]:
    staging = context.backup_root / f".staging-{job_id}"
    try:
        _prepare_directory(context.backup_root, BACKUP_DIR_MODE, "backup root")
        _reject_symlink(staging, "backup staging directory")
        staging.mkdir(mode=BACKUP_DIR_MODE)
        os.chmod(staging, BACKUP_DIR_MODE)
        pihole_dir = context.etc_root / "pihole"
        _copy_configuration(context, staging)
        for database_name in ("gravity.db", "pihole-FTL.db"):
            source = pihole_dir / database_name
            if source.exists():
                if source.is_symlink():
                    raise RuntimeError(f"SQLite source must not be a symlink: {source.name}")
                _sqlite_backup(source, staging / "pihole" / database_name)
        _manifest(staging, job_id)
        _verify_manifest(staging)
        published = context.backup_root / f"{_utc_now().replace(':', '').replace('-', '')}-{job_id}"
        os.replace(staging, published)
        _retain_newest_backups(context.backup_root)
        return [{"name": "backup", "required": True, "ok": True}], None, str(published)
    except (OSError, sqlite3.Error, ValueError, RuntimeError) as error:
        shutil.rmtree(staging, ignore_errors=True)
        return [{"name": "backup", "required": True, "ok": False, "error_output": _sanitize_output(str(error))}], "backup_failed", None


def _run_update(context: RunnerContext, job_id: str) -> tuple[list[dict[str, Any]], str | None, str | None]:
    steps, error, backup_path = _run_backup(context, job_id)
    if error:
        return steps, error, backup_path
    for name, argv in (
        ("apt_update", ["/usr/bin/apt-get", "update"]),
        ("apt_upgrade", ["/usr/bin/apt-get", "-y", "upgrade"]),
        ("pihole_update", [context.pihole_bin, "-up"]),
        ("pihole_gravity", [context.pihole_bin, "-g"]),
    ):
        step = _command_step(name, argv, context)
        steps.append(step)
        if not step["ok"]:
            return steps, "update_failed", backup_path
    check_steps, check_error = _run_check(context)
    steps.extend(check_steps)
    return steps, check_error, backup_path


def run_job(action: Action | str, context: RunnerContext) -> dict[str, Any]:
    selected_action = _as_action(action)
    _prepare_directory(context.lock_file.parent, 0o750, "lock directory")
    _reject_symlink(context.lock_file, "lock file")
    with context.lock_file.open("a+", encoding="utf-8") as lock_handle:
        try:
            fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return {"state": "failed", "error": {"code": "busy", "message": "another maintenance job is running"}}
        job_id = _job_id()
        payload: dict[str, Any] = {
            "schema_version": 1,
            "job_id": job_id,
            "action": selected_action.value,
            "state": "running",
            "started_at": _utc_now(),
            "finished_at": None,
            "steps": [],
            "result": {},
            "error": None,
        }
        try:
            _write_state(payload, context)
            if selected_action is Action.CHECK:
                steps, error = _run_check(context)
                backup_path = None
            elif selected_action is Action.BACKUP:
                steps, error, backup_path = _run_backup(context, job_id)
            else:
                steps, error, backup_path = _run_update(context, job_id)
            payload["steps"] = steps
            payload["finished_at"] = _utc_now()
            if error:
                payload["state"] = "failed"
                payload["error"] = {"code": error, "message": error.replace("_", " ")}
            else:
                payload["state"] = "succeeded"
            result: dict[str, Any] = {}
            if selected_action in {Action.CHECK, Action.UPDATE}:
                result["system"] = _system_summary()
            if backup_path:
                result["backup_path"] = backup_path
            if selected_action is Action.UPDATE:
                result["reboot_required"] = context.reboot_required_path.exists()
            payload["result"] = result
        except (OSError, RuntimeError) as error:
            payload["state"] = "failed"
            payload["finished_at"] = _utc_now()
            payload["error"] = {"code": "runner_failed", "message": _sanitize_output(str(error))}
        _write_state(payload, context, history=True)
        return payload


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if len(arguments) != 1:
        return 2
    try:
        result = run_job(arguments[0], RunnerContext())
    except ValueError:
        return 2
    return 0 if result["state"] == "succeeded" else 1


if __name__ == "__main__":
    raise SystemExit(main())
