# Betriebsreport Pi-hole + Unbound

Datum: 27.03.2026  
System: Raspberry Pi, Debian 13 (trixie), ARM64  
Zielsystem: Bewusst nur Pi-hole + Unbound, ohne Pi.Alert/NetAlertX

## 1. Zusammenfassung
Der produktive DNS-Betrieb ist funktionsfähig und stabil.  
Die Resolver-Fehlkonfiguration am Host wurde behoben, ohne die DNS-Kette Pi-hole -> Unbound zu beschädigen.

## 2. Ausgangslage und Befunde
### 2.1 Positiv vorgefunden
- pihole-FTL aktiv und stabil.
- unbound aktiv und stabil.
- Pi-hole Upstream korrekt auf 127.0.0.1#5335 gesetzt.
- DNS-Blocking funktionierte bereits.
- Pi-hole Weboberfläche erreichbar.

### 2.2 Problematische Befunde
- /etc/resolv.conf war ein defekter Symlink auf nicht vorhandene systemd-resolved Stub-Datei.
- systemd-resolved war maskiert und bewusst nicht aktiv.
- unbound-resolvconf war enabled und failed, da es gegen nicht vorhandenes systemd-resolved schreiben wollte.
- Dadurch unnötige Fehler im systemd-Fehlerstatus.

### 2.3 Nicht als Fehler im Zielsystem gewertet
- Pi.Alert/NetAlertX ist bewusst nicht Bestandteil des Zielsystems.

## 3. Vor Änderung gesicherte Artefakte
Es wurde ein Snapshot/Backup erstellt unter:
- /home/pi/dns_fix_backup_20260327_163054

Gesichert wurden:
- etc_resolv.conf.before
- unbound-resolvconf.service.before
- NetworkManager.conf.before
- pihole.toml.before
- unbound-resolvconf.systemctl-cat.before
- unbound-resolvconf.status.before

## 4. Durchgeführte Änderungen
### 4.1 Resolver-Reparatur am Host
- Defekten Symlink /etc/resolv.conf entfernt.
- Neue statische /etc/resolv.conf erstellt.

Inhalt der neuen Resolver-Datei:
- nameserver 127.0.0.1
- nameserver ::1
- options timeout:2 attempts:2

Wirkung:
- Host-Resolver ist lokal nutzbar, ohne Abhängigkeit von systemd-resolved.

### 4.2 unbound-resolvconf stillgelegt
- unbound-resolvconf deaktiviert.
- unbound-resolvconf gestoppt.
- unbound-resolvconf maskiert.
- Fehlzustand zurückgesetzt.

Wirkung:
- unbound-resolvconf erzeugt keine weiteren Laufzeitfehler.

### 4.3 DNS-Kette unverändert belassen
- Keine Änderung an Pi-hole Upstream oder Unbound-Port.
- Pi-hole -> Unbound blieb durchgehend erhalten.

## 5. Verifikation nach Umsetzung
### 5.1 Service-Status
- pihole-FTL: active
- lighttpd: inactive
- unbound: active

Hinweis:
- lighttpd ist in diesem Setup nicht für die Pi-hole-Weboberfläche erforderlich, da der integrierte Webserver antwortet.

### 5.2 systemd-Fehlerstatus
Nach der Korrektur verbleiben:
- NetworkManager-wait-online.service: failed
- pihole_exporter.service: bewusst deaktiviert (kein aktiver Fehler)

Nicht mehr enthalten:
- unbound-resolvconf.service

### 5.3 DNS-Funktionstests
- dig @127.0.0.1 github.com: NOERROR, Antwort vorhanden.
- dig @127.0.0.1 doubleclick.net: geblockt, Antwort 0.0.0.0.
- dig @127.0.0.1 -p 5335 github.com: NOERROR über Unbound.
- Host-Resolver ohne expliziten DNS-Server: erfolgreich.

### 5.4 Pi-hole Funktion
- pihole status: FTL lauscht auf Port 53 (IPv4/IPv6, UDP/TCP), Blocking aktiv.
- HTTP-Check auf /admin: Redirect auf Login vorhanden, Oberfläche erreichbar.

## 6. Behobene Befunde
- Defekte Host-Resolver-Verlinkung behoben.
- Fehlerhafte Abhängigkeit unbound-resolvconf -> systemd-resolved entfernt.
- systemd-Fehlerliste um unbound-resolvconf bereinigt.

## 7. Verbleibende Restbefunde
### 7.1 NetworkManager-wait-online
- Status: failed
- Relevanz: gering bis mittel, abhängig von Boot-Abhängigkeiten einzelner Dienste.
- Aktuelle Auswirkung: DNS-Betrieb läuft dennoch stabil.

### 7.2 pihole_exporter
- Status: bewusst deaktiviert
- Einordnung: kein aktiver Fehler im Zielsystem
- Aktuelle Auswirkung: keine auf den DNS-Kernbetrieb.

### 7.3 Pi.Alert/NetAlertX
- Status: bewusst nicht Bestandteil des Zielsystems
- Einordnung: kein Fehler.

## 8. Rollback-Anleitung
Bei Bedarf Rücknahme mit den gesicherten Dateien:

1. /etc/resolv.conf zurücksetzen
- vorhandene Datei entfernen
- etc_resolv.conf.before aus Backup zurückkopieren

2. unbound-resolvconf reaktivieren
- unmask
- enable --now

3. Ergebnis prüfen
- systemctl is-active unbound-resolvconf
- systemctl --failed
- DNS-Auflösung testen

## 9. Dokumentation für spätere Weiterentwicklung
### 9.1 Betriebsziel dauerhaft festhalten
- Zielsystem bleibt Pi-hole + Unbound ohne Pi.Alert/NetAlertX.
- Künftige Änderungen dürfen diese Zielarchitektur nicht verwässern.

### 9.2 Empfohlene nächste Arbeitspakete
1. NetworkManager-wait-online nur bei echtem Bedarf analysieren:
- Nur fixen, wenn Boot-Sequenz oder abhängige Dienste konkret betroffen sind.

2. Routine-Checks standardisieren:
- Service-Health
- DNS-Funktion
- systemd-Fehlerliste
- Weboberfläche

### 9.3 Vorschlag für wiederkehrende Checkliste
- systemctl is-active pihole-FTL unbound
- systemctl --failed
- dig @127.0.0.1 github.com
- dig @127.0.0.1 doubleclick.net
- dig @127.0.0.1 -p 5335 github.com
- dig github.com

## 10. Änderungsprotokoll
- 27.03.2026: Resolver-Reparatur abgeschlossen.
- 27.03.2026: unbound-resolvconf stillgelegt und maskiert.
- 27.03.2026: End-to-End-Verifikation durchgeführt.

## 11. Fortlaufende Analyse NetworkManager-wait-online und Skriptprüfung
- Start der Analyse: 2026-03-27 17:49:48 CET
- Scope: NetworkManager-wait-online + Repo-Skripte laut Vorgabe
- Hinweis: Report wird vor Analyse und nach jeder Änderung fortgeschrieben.
- Zwischenstand 2026-03-27 17:52:54 CET: Live-Diagnose NetworkManager-wait-online gestartet; bisheriger Befund deutet auf Boot-Timeout bei ansonsten verbundenem System hin.
- Zwischenstand 2026-03-27 17:53:29 CET: NetworkManager-wait-online zeigt Boot-Timeout (60s), System danach online; nm-online aktuell erfolgreich (Exit 0).
- Zwischenstand 2026-03-27 17:54:29 CET: Repro-Bug in scripts/post_install_check.sh identifiziert (set -e + ((COUNT++)) kann bei erstem PASS/WARN/FAIL mit Exit-Code 1 abbrechen). Minimalfix geplant.
- Änderung 2026-03-27 17:55:01 CET: scripts/post_install_check.sh minimal gefixt: PASS/WARN/FAIL-Zähler von ((COUNT++)) auf ((COUNT+=1)) umgestellt, um set -e Abbruch im non-interactive Lauf zu vermeiden.
- Zwischenstand 2026-03-27 17:55:30 CET: Zwei weitere reproduzierbare Fehlbewertungen in scripts/post_install_check.sh erkannt (Pi-hole Versions-Parsing, Upstream-Check bei mehrzeiligem TOML-Array). Minimalfix geplant.
- Zwischenstand 2026-03-27 17:57:16 CET: Korrekturpatch für post_install_check.sh erforderlich, da ein Zwischenedit mit fehlerhaftem Escaping entstanden ist; Funktion wird vollständig und sauber ersetzt.
- Ereignis 2026-03-27 17:57:55 CET: Zwischenpatch in scripts/post_install_check.sh war syntaktisch fehlerhaft; sofortige Reparatur auf sauberen Funktionsblock eingeleitet.
- Zwischenstand 2026-03-27 17:59:02 CET: Sichere Reparaturstrategie aktiviert: post_install_check.sh wird auf Repo-Stand zurückgesetzt und mit 3 minimalen belegten Fixes erneut angepasst.
- Änderung 2026-03-27 18:00:26 CET: scripts/post_install_check.sh erfolgreich stabilisiert: (1) set -e-sichere Zähler, (2) Pi-hole v6 Versions-Parsing auf Core/Pi-hole angepasst, (3) Upstream-Check für mehrzeilige TOML-Arrays korrigiert.
- Verifikation 2026-03-27 18:00:58 CET: post_install_check.sh läuft in --quick/--full non-interactive stabil (Exit 0), alle Zielskripte bash -n OK.

## 12. Analyse NetworkManager-wait-online (abgeschlossen)
- Analysezeit: 2026-03-27 18:01:36 CET
- Komponente: NetworkManager-wait-online.service

### Befund
- service ist beim Boot mit Timeout fehlgeschlagen (60s), aber das System ist danach regulär online gegangen.
- nm-online liefert im laufenden Betrieb Exit 0.
- nmcli zeigt STATE=connected und CONNECTIVITY=full.

### Belegte Ursache
- Beim Boot hat eth0 mehrfach DHCP-Timeouts erhalten (ip-config-unavailable) und erst nach weiteren Retries einen Lease erhalten.
- NetworkManager meldete "startup complete" erst nach dem Wait-Online-Zeitfenster.
- Damit ist der Befund ein Boot-Timeout-Artefakt, kein persistenter Laufzeitfehler der aktiven Netzkonnektivität.

### Änderung
- Keine Änderung an NetworkManager-wait-online (bewusst), da aktuell kein echter Betriebsfehler im laufenden Zustand vorliegt.

### Verifikation
- systemctl --failed: nur NetworkManager-wait-online bleibt failed.
- systemctl is-active pihole-FTL unbound: beide active.
- dig @127.0.0.1 github.com: NOERROR.
- nmcli general status: connected/full.

## 13. Skriptprüfung (abgeschlossen)
Geprüfte Skripte:
- scripts/console_menu.sh
- scripts/nightly_test.sh
- scripts/post_install_check.sh
- scripts/repo_selftest.sh
- scripts/lib/ui.sh

Prüfungen:
- bash -n auf allen Zielskripten: OK
- shellcheck: nicht installiert (dokumentiert)
- inhaltlicher Scan auf veraltete Annahmen gegen Soll-Zustand

### Skriptbefunde
| Skript | Befund | Ursache | Einstufung | Fix erforderlich | Fix erfolgt | Nächste konkrete Aktion |
|---|---|---|---|---|---|---|
| scripts/post_install_check.sh | Bug | set -e + ((COUNT++)) konnte non-interactive Läufe mit Exit 1 abbrechen | schwerwiegend | ja | ja | behoben und verifiziert |
| scripts/post_install_check.sh | veraltete Annahme | Versions-Parsing erwartete nur "Pi-hole version is" statt aktueller Core-Ausgabe | mittel | ja | ja | behoben und verifiziert |
| scripts/post_install_check.sh | Fehlbewertung | Upstream-Check war bei mehrzeiligem TOML-Array unzuverlässig | mittel | ja | ja | behoben und verifiziert |
| scripts/console_menu.sh | ok | keine harte Pflichtannahme zu lighttpd/systemd-resolved/Pi.Alert | leicht | nein | nein | keine |
| scripts/nightly_test.sh | ok | keine harte Pflichtannahme zu lighttpd/systemd-resolved/Pi.Alert | leicht | nein | nein | keine |
| scripts/repo_selftest.sh | ok | keine harte Pflichtannahme zu lighttpd/systemd-resolved/Pi.Alert | leicht | nein | nein | keine |
| scripts/lib/ui.sh | ok | reine UI-Hilfsfunktionen | leicht | nein | nein | keine |

### Repo-Status der Skriptkorrektur
- Geänderte Datei: scripts/post_install_check.sh
- Verifikation: --quick und --full laufen non-interactive mit Exit 0.
- Keine Änderungen an DNS-Komponenten.
- Zwischenstand 2026-03-27 18:02:04 CET: Repo-Fix wird auf neuem Branch committed; Betriebsreport bleibt lokal als laufende Betriebsdoku.
- Ereignis 2026-03-27 18:03:38 CET: Commit zunächst fehlgeschlagen wegen fehlender Git-Identität (user.name/user.email); lokales Repo-Scoped Setzen für technischen Abschluss erforderlich.
- Änderung 2026-03-27 18:03:55 CET: Repo-Fix committed auf Branch fix/post-install-check-noninteractive-v6, Commit a7601b4 (nur scripts/post_install_check.sh).
- Start GitHub-Abgleich 2026-03-27 18:14:10 CET: Repo-Sync, Branch-Übernahme des post_install_check-Fixes und Report-Korrektur begonnen.
- Änderung 2026-03-27 18:14:49 CET: Git-Identität repo-lokal auf TimInTech/gummiflip@outlook.de gesetzt; Fix-Branch und Commit a7601b4 verifiziert.
- Änderung 2026-03-27 18:16:51 CET: Report-Reststatus bereinigt: pihole_exporter und Pi.Alert/NetAlertX als kein aktiver Fehler gekennzeichnet; verbleibender technischer Restpunkt bleibt NetworkManager-wait-online.
- Verifikation 2026-03-27 18:17:19 CET: bash -n scripts/post_install_check.sh OK, --quick/--full jeweils Exit 0, pihole-FTL/unbound active, systemctl --failed zeigt ausschließlich NetworkManager-wait-online.
- Zwischenstand 2026-03-27 18:35:58 CET: Fortsetzung der Git-/Report-Finalisierung gestartet.
- Zwischenstand 2026-03-27 18:36:31 CET: Finaler Git-Abgleich durchgeführt; main ist lokal ahead 2 ggü. origin/main und push wird ausgeführt.
