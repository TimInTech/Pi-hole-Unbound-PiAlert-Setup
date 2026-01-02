# Codex Prompt — Repo-Überarbeitung (UI/Optik + Robustheit + Nightly Tests)

Du bist **Codex CLI** und arbeitest lokal im Repository. Arbeite **maximal autonom**: lies zuerst, dann ändere in kleinen, reviewbaren Schritten und validiere zwischendurch.

## Nicht verhandelbar (Guardrails)

- **Keine Secrets loggen oder ausgeben**: niemals API-Keys/Tokens ausgeben; niemals `.env`/env-Dateien `cat`/`echo`en.
- **Keine neuen user-facing Features/Flows**: keine neuen Menüs/Seiten/Optionen erfinden; nur vereinheitlichen + härten.
- **Styling zentral**: keine rohen ANSI-Sequenzen und kein ad-hoc Farbkram in Skripten.
- **Pi-hole v6 only**: keine v5-Kommandos/Annahmen re-introducen. Upstreams/Resolver-Konfig muss v6-konform passieren (insb. via `pihole.toml`, nicht über legacy Pfade).
- **Tests sind safe**: Nightly/Tests nur non-interactive; nur `sudo -n` (wenn nicht möglich → warnen + skippen). **Nie** `apt upgrade` im Testlauf. Keine Docker-prune/cleanup-Aktionen.

## Unbedingt zuerst (MANDATORY)

Hinweis: `report.md` enthält Historie. Bindend sind `AGENTS.md` + diese Datei.

1) Lies `AGENTS.md` und `report.md` komplett.
2) Mache eine **Audit-only** Runde (keine Edits): finde duplizierte UI/Logging-Patterns, ANSI-Verwendung, `echo -e`, fragile Bash-Patterns.
3) Erst danach refactorst du, und zwar **unter Nutzung der existierenden neuen Dateien**:
   - `scripts/lib/ui.sh`
   - `scripts/nightly_test.sh`
   - vorhandene lokale Änderungen in `install.sh`
   - `CODEX_PROMPT.md` (diese Datei)
   Diese Artefakte **nicht verwerfen oder revertieren**.

## Quellen / Regressionen

- Primär (falls vorhanden): `debiantestinsall.txt` im Repo.
- Sekundär: http://192.168.178.200:8085/gummi/Pi-hole-Unbound-PiAlert-Setup/src/branch/main/debiantestinsall.txt

- Wenn die HTTP-Quelle nicht erreichbar ist: warnen und mit lokalem Fixture weiterarbeiten (nicht blockieren).

Regressions, die nicht wieder auftauchen dürfen:
- systemd Python suite: `203/EXEC` / `200/CHDIR`
- Pi-hole v6 “Not Ready” durch leere Upstreams (Upstreams müssen in `pihole.toml` gesetzt sein)
- stale State Flags (State ist nie Source of Truth)

## Zielbild

1) **Einheitliche UI/Optik** über alle Bash-Skripte:
   - Eine zentrale UI/Logging-Lib: `scripts/lib/ui.sh`
   - Kanonische Log-Funktionen: `log_info`, `log_ok`, `log_warn`, `log_err`
   - `NO_COLOR` und TTY-Detection gelten repo-weit
   - Kein `echo -e` mehr (nur `printf`)

2) **Robustheit/Idempotenz**:
   - State-File ist Optimierung, nicht Wahrheit → immer Realität prüfen (z.B. `systemctl`, Dateien, Permissions)
   - Tempfiles nur via `mktemp` (kein statisches `/tmp/...`)
   - Überall robuste Pfade: `SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"` statt CWD-Annahmen

3) **Overnight Test Runner**:
   - `scripts/nightly_test.sh` soll lange laufen können, interruptible (Ctrl+C) und trotzdem Summary liefern
   - `bash -n` + `scripts/repo_selftest.sh` müssen Teil des Runs sein
   - optional `shellcheck` / `shfmt` wenn installiert (warn + weiter, wenn nicht)
   - Installer-Übungen nur safe (DRY_RUN / resume loops) und nur wenn `sudo -n true` klappt
   - Timeouts auf lange Schritte setzen

## Fokus-Dateien

- `install.sh`
- `scripts/console_menu.sh`
- `scripts/post_install_check.sh`
- `scripts/repo_selftest.sh`
- `tools/pihole_maintenance_pro.sh`
- `scripts/lib/ui.sh`
- `scripts/nightly_test.sh`

## Vorgehen (ohne Rückfragen, soweit möglich)

### Phase A — Audit (read-only)
- Suche in allen `*.sh` nach:
  - ANSI (`\033[`), `echo -e`, duplizierten log_* Funktionen, Prompt/Select Code, fragile Path-Checks
- Dokumentiere kurz: Wo ist es, was wird vereinheitlicht (keine Fixes in Phase A).

### Phase B — Zentralisiertes UI-Modul
- Nutze/erweitere `scripts/lib/ui.sh` als einzige Quelle für:
  - Color init (TTY + NO_COLOR)
  - `log_info/log_ok/log_warn/log_err`
  - Header/Section Helfer
  - Prompt-Helfer (nur wenn bereits vorhandene UX dadurch 1:1 abbildbar ist)
- Danach refactorst du die Fokus-Dateien, sodass sie dieses Modul sourcen.

### Phase C — Konsistenzrefactor
- Vereinheitliche Logging-Layout und Fehlermeldungen (keine neuen Inhalte/Flows).
- Halte die bestehende UX strikt bei.

### Phase D — Nightly Tests
- Erweitere `scripts/nightly_test.sh` (nicht ersetzen), so dass:
  - Quick Checks laufen (`bash -n`, `scripts/repo_selftest.sh`)
  - optional `shellcheck`/`shfmt` laufen
  - Installer safe exercised wird (nur mit `sudo -n`, kein apt upgrade)
  - Logs gesammelt werden + Summary + korrekter Exit-Code

### Phase E — Abschluss / DoD
- Am Ende muss grün sein:
  - `bash -n` auf allen relevanten Scripts
  - `scripts/repo_selftest.sh`
  - `scripts/nightly_test.sh` (kurzer Run)
- Hänge an `report.md` einen Abschnitt **„Codex Änderungen“** an:
  - Was geändert wurde (Dateien)
  - Wie man testet (konkrete Commands)
  - Rest-Risiken / Follow-ups (max 5)

## Output-Format (am Ende)

- Was geändert wurde (Dateien + 1–2 Sätze je Datei)
- Wie man testet (konkrete Commands)
- Offene Risiken/Follow-ups (max. 5 Punkte)

Jetzt starten.
