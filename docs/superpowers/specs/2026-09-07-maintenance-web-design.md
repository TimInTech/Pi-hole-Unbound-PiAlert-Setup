# Sichere Pi-hole-Wartungs-Weboberfläche

Datum: 2026-09-07

## Ziel

Die vorhandene lokale Pi-hole-Suite erhält eine deutschsprachige Weboberfläche,
über die ein Administrator den Systemzustand prüfen, ein verifiziertes Backup
erstellen und einen kontrollierten Update-Lauf starten kann. Die Oberfläche ist
auf dem produktiven Raspberry Pi unter `https://pi.hole:8443/` und
`https://192.168.178.2:8443/` erreichbar.

## Plattform und Bestand

- Zielsystem: Raspberry Pi, Debian 13 (Trixie), systemd, Pi-hole v6 und Unbound.
- Bestehender interner API-Dienst: FastAPI/Uvicorn als Benutzer `pihole-suite`
  auf `127.0.0.1:8090`.
- Bestehende Konfiguration: `/etc/pihole-suite/pihole-suite.env`, Modus `0640`,
  Eigentümer `root:pihole-suite`.
- Vorhandener Suite-Schlüssel `SUITE_API_KEY` dient als Anmeldepasswort. Er wird
  weder in HTML noch in Logs oder API-Antworten ausgegeben.
- Öffentlicher TLS-Endpunkt: Caddy auf TCP-Port `8443`; Uvicorn bleibt auf
  Loopback gebunden.

## Architektur und Vertrauensgrenzen

```text
Browser --HTTPS :8443--> Caddy --HTTP loopback :8090--> FastAPI (unprivilegiert)
                                                           |
                                                           | exakt erlaubte
                                                           | systemctl-Aufrufe
                                                           v
                    pihole-maintenance-{check,backup,update}.service (root, oneshot)
                                                           |
                                                           v
                                         root-eigener Python-Runner
```

Der Webdienst erhält keine allgemeinen Root-Rechte und führt keine Shellstrings
aus. Er darf über `sudo -n` ausschließlich die drei fest benannten systemd-Units
starten. Die Units rufen einen root-eigenen, nicht durch `pihole-suite`
beschreibbaren Runner mit einer fest verdrahteten Aktion auf.

Der Runner serialisiert sämtliche Aktionen über
`/run/lock/pihole-maintenance-web.lock`. Damit können Web-, Cron- und manuelle
Läufe nicht gleichzeitig Pi-hole, APT oder die Backupdaten verändern.

## Authentifizierung und HTTP-Sicherheit

- Login per `POST /api/session` mit dem vorhandenen `SUITE_API_KEY`.
- Vergleich mit `hmac.compare_digest`.
- Erfolgreicher Login erzeugt eine zufällige serverseitige Sitzung mit 30 Minuten
  Inaktivitätszeit und maximal 8 Stunden Gesamtlaufzeit.
- Cookie: `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/`.
- Zustandsänderungen erfordern `POST`, einen sitzungsgebundenen CSRF-Token sowie
  einen erlaubten `Origin` (`https://pi.hole:8443` oder
  `https://192.168.178.2:8443`).
- Maximal fünf fehlgeschlagene Anmeldungen je Client innerhalb von fünf Minuten;
  danach Sperre bis zum Ende des Zeitfensters.
- Kein CORS. Erlaubte Hosts: `pi.hole`, `192.168.178.2`, `127.0.0.1`, `localhost`.
- Produktiv sind Swagger und OpenAPI deaktiviert.
- Sicherheitsheader: CSP ohne Fremdquellen, `frame-ancestors 'none'`,
  `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer` und HSTS.
- Caddy akzeptiert Port 8443 nur aus `192.168.178.0/24` und von Loopback.

## Aktionen

### Systemcheck

Die Aktion `check` verändert das System nicht. Sie ermittelt:

- Host, Betriebssystem, Kernel, Architektur, Laufzeit, Last, RAM, Root-Dateisystem
  und Temperatur;
- Versionen und Aktivzustand von Pi-hole FTL und Unbound;
- Listener auf Port 53 und 5335;
- DNS-Auflösung über Pi-hole (`127.0.0.1:53`) und Unbound
  (`127.0.0.1:5335`);
- verfügbaren APT-Aktualisierungszähler nach einem rein lesenden
  `apt-get -s upgrade`.

Ein fehlgeschlagener Pflichtcheck erzeugt den Gesamtstatus `failed` und einen
von null verschiedenen Prozessstatus. Optionale Sensordaten dürfen `warning`
erzeugen. Es werden keine Domains, Clients, MAC-Adressen, sudoers-Inhalte,
Shadow-Daten oder fehlgeschlagenen SSH-Logins ausgegeben.

### Backup

Die Aktion `backup` erstellt zunächst ein Staging-Verzeichnis unter
`/var/backups/pihole-suite/.staging-<job-id>` mit Modus `0700`. Enthalten sind:

- `/etc/pihole/pihole.toml` und vorhandene relevante Pi-hole-Konfigurationsdateien;
- `/etc/unbound`;
- Drop-ins von `pihole-FTL.service` und `unbound.service`;
- konsistente SQLite-Online-Backups von `gravity.db` und `pihole-FTL.db`, sofern
  vorhanden;
- `manifest.json` mit SHA-256-Prüfsummen, Größen, Zeitpunkt, Host und Versionen.

Jede gesicherte SQLite-Datenbank muss `PRAGMA quick_check` mit Ergebnis `ok`
bestehen. Alle Manifest-Prüfsummen werden nach dem Schreiben erneut geprüft.
Erst danach wird das Staging-Verzeichnis atomar auf
`/var/backups/pihole-suite/<UTC-Zeit>-<job-id>` umbenannt. Jeder Fehler bricht den
Job ab und darf nicht als erfolgreich gemeldet werden. Nach erfolgreicher
Verifikation bleiben die zehn neuesten Backups erhalten. Restore, Download und
Löschen werden nicht über das Web angeboten.

### Update

Die Aktion `update` führt zwingend zuerst dieselbe verifizierte Backupfunktion
aus. Nur nach Erfolg folgen in dieser Reihenfolge:

1. `apt-get update`
2. `DEBIAN_FRONTEND=noninteractive apt-get -y upgrade`
3. `pihole -up`
4. `pihole -g`
5. vollständiger Systemcheck

`autoremove`, freies Paketmanagement, frei wählbare Flags und automatische
Neustarts des Raspberry Pi sind ausgeschlossen. Ein Fehler beendet die Kette;
der Jobstatus bleibt `failed`. Falls `/var/run/reboot-required` existiert, zeigt
das Ergebnis ausschließlich `reboot_required: true`; ein Reboot wird nie
automatisch ausgelöst.

## Jobzustand und Webdarstellung

Der Runner schreibt Zustände atomar als JSON nach
`/var/lib/pihole-suite/jobs/current.json` und zusätzlich als Historie nach
`/var/lib/pihole-suite/jobs/<job-id>.json`. Dateien erhalten
`root:pihole-suite` und Modus `0640`.

Das Schema enthält mindestens `schema_version`, `job_id`, `action`, `state`,
`started_at`, `finished_at`, `steps`, `result` und `error`. Zulässige Zustände
sind `running`, `succeeded` und `failed`. Befehlsausgaben werden auf eine feste
Länge begrenzt und von Steuerzeichen bereinigt.

Die Weboberfläche zeigt drei Karten für Systemcheck, Backup und Update, den
aktuellen Jobstatus, die einzelnen Schritte, den Backup-Pfad, den
Reboot-Hinweis und klare Fehlertexte. Backup und Update verlangen eine sichtbare
Bestätigung; Update zusätzlich die exakte Eingabe `UPDATE`.

## Dateieigentum und systemd

- Anwendungscode und virtuelle Umgebung: `root:root`, nicht für
  `pihole-suite` beschreibbar.
- Veränderliche Suite-Daten: `root:pihole-suite`, nur die expliziten
  Zustandsverzeichnisse sind für den Dienst lesbar beziehungsweise für
  Sessiondaten schreibbar.
- Webdienst behält `NoNewPrivileges=true`, leere `CapabilityBoundingSet`,
  `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true` und die
  bestehenden Kernel-/Namespace-Schutzoptionen.
- Root-Jobs sind kurzlebige Oneshots, verwenden absolute Pfade, einen festen
  `PATH`, `UMask=0077`, Zeitlimits und keine benutzerkontrollierten Argumente.

## Installation und Rollback

Ein idempotenter Installer installiert App, Runner, Units, sudoers-Regel und
Caddy-Konfiguration. Er validiert Python, sudoers, systemd-Units und Caddy vor
dem Aktivieren. Vor dem Austausch werden die zuvor installierten Artefakte in
einem zeitgestempelten Root-Verzeichnis unter
`/var/backups/pihole-suite-deploy/` gesichert.

Rollback stellt genau diese Artefakte wieder her, lädt systemd/Caddy neu und
prüft anschließend Pi-hole, Unbound sowie DNS. Backupdateien des Benutzers
werden durch Rollback nicht gelöscht.

## Akzeptanzkriterien auf dem produktiven Pi

1. Unauthentisierte Wartungs-API-Aufrufe liefern `401`; falscher Origin oder
   CSRF-Token liefert `403`.
2. HTTPS-Port 8443 ist aus dem LAN erreichbar, Port 8090 ausschließlich lokal.
3. Der FastAPI-Prozess läuft nicht als Root und kann keine beliebigen
   `sudo`-Befehle ausführen.
4. Ein über die HTTPS-Web-API gestarteter Systemcheck endet `succeeded` und
   bestätigt Pi-hole, Unbound sowie beide DNS-Pfade.
5. Ein über die HTTPS-Web-API gestartetes Backup endet `succeeded`; Manifest,
   Prüfsummen und vorhandene SQLite-Backups werden erneut unabhängig geprüft.
6. Ein über die HTTPS-Web-API gestartetes Update endet `succeeded`; es besitzt
   ein verifiziertes Vorab-Backup und der abschließende Systemcheck ist grün.
7. Gleichzeitige zweite Jobstarts werden mit HTTP 409 abgewiesen.
8. Nach allen Tests sind `pihole-FTL`, `unbound`, `pihole-suite` und `caddy`
   aktiv; DNS über Port 53 und 5335 funktioniert.
