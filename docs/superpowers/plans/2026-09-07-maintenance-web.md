# Secure Pi-hole Maintenance Web Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Build and deploy an authenticated HTTPS maintenance panel that safely runs system check, verified backup, and update jobs on the production Pi-hole.

**Architecture:** Extend the loopback-only FastAPI suite with session-authenticated maintenance routes and a static UI. The web process may start only three fixed root systemd oneshots; a root-owned Python runner serializes jobs and writes atomic JSON state. Caddy exposes the app on HTTPS port 8443 to the local management subnet.

**Tech Stack:** Python 3.11+ standard library, FastAPI, Uvicorn, pytest, Bash 5+, systemd, sudoers, Caddy.

**Spec:** docs/superpowers/specs/2026-09-07-maintenance-web-design.md

## Global Constraints

- Public URLs are exactly https://pi.hole:8443/ and https://192.168.178.2:8443/; Uvicorn remains on 127.0.0.1:8090.
- The FastAPI service runs as pihole-suite, never as root, and accepts no arbitrary command, path, package, URL, or shell input.
- Allowed root actions are exactly check, backup, and update; they are serialized with /run/lock/pihole-maintenance-web.lock.
- Update order is verified backup, apt-get update, noninteractive apt-get -y upgrade, pihole -up, pihole -g, then full check; no autoremove and no reboot.
- Backups live below /var/backups/pihole-suite, use SQLite online backup, manifest SHA-256 verification, atomic publication, mode 0700, and retention of ten verified backups.
- Job JSON lives below /var/lib/pihole-suite/jobs, is atomic, root:pihole-suite mode 0640, and never contains domains, clients, MACs, sudoers, shadow data, failed-login data, API keys, cookies, or CSRF tokens.
- Browser authentication uses the existing SUITE_API_KEY only as a submitted password; successful login replaces it with a server-side session cookie using Secure, HttpOnly, and SameSite=Strict.
- All mutating API calls require an authenticated session, an exact allowed Origin, and a matching CSRF token.
- Production OpenAPI/Swagger is disabled and CORS is not enabled.
- Every Bash file added or changed uses set -euo pipefail.
- Production deployment is not complete until all three actions have been started through the HTTPS API and independently verified on pi@192.168.178.2.

---

### Task 1: Privileged maintenance runner

**Files:**
- Create: maintenance_runner.py
- Create: tests/test_maintenance_runner.py

**Interfaces:**
- Consumes: one fixed action from systemd: check, backup, or update.
- Produces: main(argv: Sequence[str] | None = None) -> int and run_job(action: Action, context: RunnerContext) -> dict[str, Any].
- Produces for Task 2: /var/lib/pihole-suite/jobs/current.json with state running, succeeded, or failed.

- [ ] **Step 1: Write failing runner contract tests**

Use temporary etc, state, backup, and lock directories plus a recording command executor. Tests must cover unknown action rejection, failed DNS as failed status, corrupt SQLite preventing publication, and failed required backup preventing apt.

~~~python
def test_rejects_unknown_action_without_commands(tmp_path):
    context, commands = make_context(tmp_path)
    with pytest.raises(ValueError, match="unsupported action"):
        run_job("shell", context)
    assert commands.calls == []

def test_update_stops_before_apt_when_backup_fails(tmp_path):
    context, commands = make_context(tmp_path, corrupt_database=True)
    result = run_job("update", context)
    assert result["state"] == "failed"
    assert ["/usr/bin/apt-get", "update"] not in commands.calls
~~~

- [ ] **Step 2: Run pytest -q tests/test_maintenance_runner.py and verify collection fails because the module is absent.**

- [ ] **Step 3: Implement immutable paths, injectable command execution, an exact action enum, bounded sanitized output, UTC job IDs, and atomic JSON writes using os.replace. Reject symlink state and backup roots.**

- [ ] **Step 4: Add failing tests for nonblocking flock, running then terminal transitions, state mode 0640, backup mode 0700, failed staging cleanup, ten-backup retention, SHA-256 verification, and exact update command order.**

~~~python
def test_second_job_reports_busy(tmp_path):
    context, _ = make_context(tmp_path)
    with held_lock(context.lock_file):
        result = run_job("check", context)
    assert result["error"]["code"] == "busy"

def test_update_command_order(tmp_path):
    context, commands = make_context(tmp_path)
    assert run_job("update", context)["state"] == "succeeded"
    assert update_calls(commands.calls) == [
        ["/usr/bin/apt-get", "update"],
        ["/usr/bin/apt-get", "-y", "upgrade"],
        [context.pihole_bin, "-up"],
        [context.pihole_bin, "-g"],
    ]
~~~

- [ ] **Step 5: Run the new focused tests and verify they fail for the missing behavior.**

- [ ] **Step 6: Implement system checks, SQLite online backup plus quick_check, config copying without symlink traversal, manifest generation and re-verification, atomic backup publication, retention, update sequencing, and final check.**

- [ ] **Step 7: Run pytest -q tests/test_maintenance_runner.py and require zero failures and warnings.**

- [ ] **Step 8: Run Python compilation and git diff --check, then commit as feat: add privileged maintenance job runner.**

---

### Task 2: Authenticated maintenance API and browser UI

**Files:**
- Create: maintenance_web.py
- Create: web/maintenance.html
- Create: web/maintenance.css
- Create: web/maintenance.js
- Create: tests/test_maintenance_web.py
- Modify: start_suite.py

**Interfaces:**
- Consumes Task 1 state schema and exact actions.
- Produces create_maintenance_router(settings: MaintenanceSettings) -> APIRouter and the UI at /.
- Dispatches only /usr/bin/sudo -n /usr/bin/systemctl start --no-block pihole-maintenance-ACTION.service.

- [ ] **Step 1: Write failing TestClient tests for unauthenticated 401, login secrecy and cookie flags, missing or wrong CSRF 403, wrong Origin 403, and login rate limiting.**

~~~python
def test_job_status_requires_session(client):
    assert client.get("/api/maintenance/status").status_code == 401

def test_update_rejects_missing_csrf(client, authenticated_cookie):
    response = client.post(
        "/api/maintenance/update",
        cookies=authenticated_cookie,
        headers={"Origin": "https://pi.hole:8443"},
    )
    assert response.status_code == 403
~~~

- [ ] **Step 2: Run pytest -q tests/test_maintenance_web.py and verify collection fails because the module is absent.**

- [ ] **Step 3: Implement constant-time key comparison, random server-side sessions, 30-minute idle and 8-hour absolute expiry, exact Host/Origin allowlists, cookie flags, rate limiting, security headers, and disabled production docs.**

- [ ] **Step 4: Add failing tests for the fixed systemctl argv, running-job 409, unknown-route 404, malformed or oversized state rejection, logout, and response headers.**

~~~python
def test_check_dispatches_only_fixed_unit(client, session, dispatcher):
    response = post_action(client, session, "check")
    assert response.status_code == 202
    assert dispatcher.calls == [[
        "/usr/bin/sudo", "-n", "/usr/bin/systemctl", "start", "--no-block",
        "pihole-maintenance-check.service",
    ]]

def test_unknown_action_is_not_routable(client, session):
    assert post_action(client, session, "../../bin/sh").status_code == 404
~~~

- [ ] **Step 5: Run the dispatch tests and verify they fail for missing routes and dispatch behavior.**

- [ ] **Step 6: Implement three explicit POST routes, bounded schema-checked state reading, fixed dispatch, and no raw journal output.**

- [ ] **Step 7: Build an accessible German login/dashboard UI. Backup requires confirmation; update requires exact UPDATE text. JavaScript keeps CSRF only in memory, uses textContent for server values, and polls every two seconds only while running.**

- [ ] **Step 8: Add tests for UI controls, MIME types, no API-key output, docs 404, and CSP/HSTS headers. Run the entire web suite until clean.**

- [ ] **Step 9: Run both Python suites, compile start_suite.py and maintenance_web.py, run git diff --check, then commit as feat: add authenticated maintenance web panel.**

---

### Task 3: Hardened system integration and installer

**Files:**
- Create: deploy/pihole-maintenance-check.service
- Create: deploy/pihole-maintenance-backup.service
- Create: deploy/pihole-maintenance-update.service
- Create: deploy/pihole-maintenance-web.sudoers
- Create: deploy/Caddyfile.maintenance
- Create: scripts/install_maintenance_web.sh
- Create: scripts/rollback_maintenance_web.sh
- Create: tests/test_install_maintenance_web.sh
- Modify: install.sh

**Interfaces:**
- Consumes /usr/local/libexec/pihole-maintenance-runner ACTION.
- Produces HTTPS :8443, three root oneshots, exact sudo authorization, root-owned app files, deploy backup, and rollback.

- [ ] **Step 1: Write a failing staged-install shell test that uses a temporary destination root and checks all paths, file modes, root-owned-code intent, sudoers syntax, and systemd units.**

~~~bash
test "$(stat -c %a "$DESTDIR/usr/local/libexec/pihole-maintenance-runner")" = 755
test "$(stat -c %a "$DESTDIR/var/lib/pihole-suite/app/start_suite.py")" = 644
grep -F "/usr/bin/systemctl start --no-block pihole-maintenance-update.service"   "$DESTDIR/etc/sudoers.d/pihole-maintenance-web"
~~~

- [ ] **Step 2: Run bash tests/test_install_maintenance_web.sh and verify RED because artifacts are absent.**

- [ ] **Step 3: Create three fixed units with UMask 0077, fixed PATH, 15-minute check/backup timeout, 120-minute update timeout, and no user-controlled arguments. Create exact sudoers commands. Configure Caddy :8443 with tls internal, LAN/loopback restriction, and loopback proxy to 8090.**

- [ ] **Step 4: Implement an idempotent set -euo pipefail installer. Live mode requires root and Caddy, backs up replaced artifacts, installs code as root:root, creates explicit state ownership, validates sudoers/units/Caddy, reloads services, and checks loopback health. Staged mode touches no services.**

- [ ] **Step 5: Implement rollback constrained to a resolved nonsymlink directory below /var/backups/pihole-suite-deploy. Restore only manifest-listed artifacts, validate, reload, and verify DNS; never remove user backups.**

- [ ] **Step 6: Add main-installer flags --with-maintenance-web and --skip-maintenance-web. Default stays skipped; enabled mode delegates after the Python suite succeeds.**

- [ ] **Step 7: Run the staged installer test, Bash syntax checks, both Python suites, and git diff --check; require zero failures.**

- [ ] **Step 8: Commit as feat: install hardened maintenance web services.**

---

### Task 4: Documentation, review, and production acceptance

**Files:**
- Modify: README.de.md
- Modify: README.md
- Modify: docs/CONSOLE_MENU.md
- Create: docs/MAINTENANCE_WEB.md
- Modify only after live verification: /home/z2-ubuntu/Wissensbasis/10_Projekte/Pi-hole-Unbound-PiAlert-Setup/Pi-hole Unbound PiAlert Setup Handover 2026-09-01.md

**Interfaces:**
- Consumes Tasks 1-3 and produces operator guidance plus authoritative live evidence.

- [ ] **Step 1: Document exact installation, URLs, local key retrieval without shell-history exposure, action semantics, job state, backup contents, certificate trust, security boundary, verification, and rollback. Include no real secret or private raw log.**

- [ ] **Step 2: Run pytest -q, repo selftest, staged install test, all Bash syntax checks, ShellCheck when available, and git diff --check.**

- [ ] **Step 3: Complete an independent whole-branch security and spec review. Fix every Critical or Important issue and rerun covering tests.**

- [ ] **Step 4: Over verified SSH, capture and inspect a root-owned pre-deployment backup of current suite app, unit, Caddy/sudoers artifacts if present, and service state.**

- [ ] **Step 5: Transfer only reviewed tracked files to a fresh /tmp directory, verify their SHA-256 manifest, install Caddy from its signed official repository if absent, and run the maintenance web installer.**

- [ ] **Step 6: Through HTTPS, prove 401 without session, 403 for wrong Origin or CSRF, 404 for unknown action, and 409 for a simultaneous second job. Keep the Suite key and cookie jar inside the remote shell and remove temporary credentials.**

- [ ] **Step 7: Through HTTPS, start check and require succeeded. Start backup and independently verify manifest, hashes, SQLite quick_check, ownership, and mode. Start update and require succeeded, a verified pre-update backup, and a passing final check.**

- [ ] **Step 8: Require pihole-FTL, unbound, pihole-suite, and caddy active; successful DNS on ports 53 and 5335; loopback-only 8090; LAN HTTPS 8443; non-root FastAPI UID; and denial of an unlisted sudo command.**

- [ ] **Step 9: Append the final architecture, verified production state, exact rollback point, and genuine blockers to the existing Vault handover. Run diff checks, secret scan, and the canonical Vault sync helper.**

- [ ] **Step 10: Commit documentation as docs: document maintenance web operations and record exact acceptance evidence. Mark complete only when every spec criterion has current direct evidence.**

