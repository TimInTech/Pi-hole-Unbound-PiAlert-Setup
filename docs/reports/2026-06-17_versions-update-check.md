# Versions-/Update-Check Pi-hole + Unbound + NetAlertX

Datum: 2026-06-17
Scope: Repository-Check, keine produktiven Updates, keine Raspberry-Pi-Serviceaenderungen, kein Push.

## Kurzfazit

Die Installationsstrategie ist grundsaetzlich aktuell: Pi-hole wird im Host-Modus ueber den offiziellen Installer bezogen und nicht auf eine Patch-Version gepinnt, der Container-Modus nutzt `pihole/pihole:latest`, Unbound kommt aus den Debian-Paketquellen, und NetAlertX nutzt `jokobsk/netalertx:latest`.

Empfohlen wurden nur Dokumentations- und Benennungsanpassungen: Pi-hole-Badge auf `v6.x`, manuelle Update-Checkliste, vollstaendigere APT-Voraussetzungen und einheitliche Bezeichnung `NetAlertX (formerly Pi.Alert)`.

## Komponenten

| Komponente | Repo-/Script-Referenz | Aktueller Stand am 2026-06-17 | Handlungsbedarf | Risiko | Empfehlung |
|---|---|---:|---|---|---|
| Pi-hole Core | `README.md`, `README.de.md`, `install.sh` Host-Modus via `https://install.pi-hole.net` | Upstream `v6.4.2`, veroeffentlicht 2026-04-24 | Kein Code-Pin-Update | Niedrig, weil Host-Installer bewusst dem offiziellen Kanal folgt | Badge nicht auf Patch-Version pinnen; `v6.x` dokumentieren |
| Pi-hole Web | Kein separates Repo-Badge; Bestandteil der Pi-hole-Installation | Upstream `v6.5.1`, veroeffentlicht 2026-06-14 | Kein separater Repo-Pin vorhanden | Niedrig | Im Report festhalten; Updates ueber `pihole -up` |
| Pi-hole FTL | `scripts/post_install_check.sh`, systemd-Service `pihole-FTL` | Upstream `v6.6.2`, veroeffentlicht 2026-05-11 | Kein separater Repo-Pin vorhanden | Niedrig | Im Report festhalten; Updates ueber `pihole -up` |
| Pi-hole Container-Modus | `install.sh` nutzt `pihole/pihole:latest` | Rolling Image-Tag | Kein Versions-Pin angefragt | Mittel, weil `latest` reproduzierbare Deployments erschwert | Fuer Produktivbetrieb vor `docker pull` Backup/Window nutzen |
| Unbound | `install.sh` installiert `unbound`, `unbound-host`, `unbound-anchor`, `dns-root-data` per `apt` | Upstream `1.25.1` vom 2026-05-20; Debian Bookworm `1.17.1-2+deb12u4`; Debian Trixie `1.22.0-2+deb13u3` | Kein Wechsel auf Upstream-Tarball | Niedrig bis mittel, abhaengig von Debian Security Backports | Debian-Pakete bleiben massgeblich; `apt list --upgradable` dokumentieren |
| NetAlertX | `install.sh` nutzt `jokobsk/netalertx:latest`, Host-Networking, `/opt/netalertx/data:/data`, Port `20211` | Upstream `v26.6.3`, veroeffentlicht 2026-06-02 | Keine funktionale Migration noetig | Mittel, weil `latest` Updates Breaking Changes enthalten koennen | Legacy-Text auf `NetAlertX (formerly Pi.Alert)` vereinheitlichen; vor Updates Release Notes pruefen |
| APT-Voraussetzungen | `install.sh` Paketliste | Installer installiert `unbound`, `unbound-host`, `unbound-anchor`, `dns-root-data`, `ca-certificates`, `curl`, `dnsutils`, `iproute2`, `python3`, `python3-venv`, `python3-pip`, `git`, `openssl`, `sqlite3`, `jq`; optional `docker.io` | README-Liste war unvollstaendig | Niedrig | README/README.de mit Installer-Liste abgleichen |
| Python-Requirements | `requirements.txt` | Constraints sind offen innerhalb bestehender Major-Grenzen; `pytest` bleibt konservativ `<9.0.0` | Kein Pin-Update noetig | Niedrig | Keine Aenderung ohne konkreten Test- oder API-Grund |

## Manuelle Update-Kommandos

Diese Kommandos sind als Wartungscheck gedacht und werden durch den Installer nicht automatisch ausgefuehrt:

```bash
pihole -v
sudo pihole -up
apt list --upgradable
docker pull jokobsk/netalertx:latest
```

Vor produktiven Updates sollte ein Rescue-Backup erstellt werden.

## Quellen

- Pi-hole Core latest release: <https://api.github.com/repos/pi-hole/pi-hole/releases/latest>
- Pi-hole Web latest release: <https://api.github.com/repos/pi-hole/web/releases/latest>
- Pi-hole FTL latest release: <https://api.github.com/repos/pi-hole/FTL/releases/latest>
- Unbound latest release: <https://api.github.com/repos/NLnetLabs/unbound/releases/latest>
- NetAlertX latest release: <https://api.github.com/repos/jokob-sk/NetAlertX/releases/latest>
- Debian Bookworm `unbound`: <https://packages.debian.org/bookworm/unbound>
- Debian Trixie `unbound`: <https://packages.debian.org/trixie/unbound>
