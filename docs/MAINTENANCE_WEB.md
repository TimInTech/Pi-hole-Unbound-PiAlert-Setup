# Pi-hole-Wartungsoberfläche

Die Wartungsoberfläche stellt genau drei kontrollierte Aktionen bereit:
Systemcheck, verifiziertes Backup und Update. Sie ist nach erfolgreicher
Produktionsabnahme unter `https://pi.hole:8443/` sowie
`https://192.168.178.2:8443/` erreichbar.

## Voraussetzungen und Installation

Der Webdienst bleibt verbindlich auf `127.0.0.1:8090`; ein abweichender
`SUITE_HOST` wird beim Start abgewiesen. Caddy veröffentlicht ausschließlich
HTTPS auf Port 8443 für `192.168.178.0/24` und Loopback. Für Caddy auf Debian
oder Raspberry Pi OS ist das offizielle Stable-Repository zu verwenden:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

Danach installiert der vorhandene Projekt-Installer den Wartungsdienst gezielt:

```bash
sudo ./install.sh --with-maintenance-web
```

Ohne diese Option bleibt die öffentliche Wartungsfreigabe deaktiviert. Ein
Dry-Run installiert oder aktiviert die Wartungsoberfläche nicht:

```bash
sudo ./install.sh --dry-run --with-maintenance-web
```

Die Caddy-Konfiguration verwendet `tls internal`. Der verwendete interne
Aussteller muss auf den administrierenden Clients über den vorgesehenen,
vertrauenswürdigen CA-Verteilweg installiert werden. Keine Browserwarnung
wegklicken und kein Zertifikatsschutz deaktivieren.

## Anmeldung und Bedienung

Das Anmeldekennwort ist der bestehende `SUITE_API_KEY`. Es wird nicht in der
Shell-Historie gespeichert, wenn es lokal nur ausgegeben und direkt in das
Passwortfeld eingegeben wird:

```bash
sudo awk -F= '$1 == "SUITE_API_KEY" { print $2 }' /etc/pihole-suite/pihole-suite.env
```

Nach erfolgreicher Anmeldung verwendet der Browser eine kurzlebige,
serverseitige Sitzung. Das Kennwort wird nicht als Cookie, API-Antwort oder
Jobzustand gespeichert. Backup verlangt eine sichtbare Bestätigung; Update
verlangt zusätzlich die exakte Eingabe `UPDATE`.

## Aktionen und Jobzustand

`Systemcheck` prüft Pi-hole FTL, Unbound, lokale DNS-Pfade auf 53 und 5335,
Konfiguration, Listener und eine lesende APT-Simulation. Ein Pflichtfehler
macht den Job fehlerhaft.

`Backup` erstellt ein SQLite-Online-Backup von vorhandenen Pi-hole-Datenbanken,
kopiert Pi-hole-/Unbound-Konfiguration ohne Symlink-Traversierung und
veröffentlicht das Ergebnis erst nach `quick_check` und Manifest-Prüfsummen.
Backups liegen unter `/var/backups/pihole-suite/`, sind mit `0700` geschützt und
werden auf die zehn neuesten verifizierten Sicherungen begrenzt.

`Update` erstellt zuerst dasselbe verifizierte Backup und führt danach in fester
Reihenfolge `apt-get update`, nichtinteraktives `apt-get -y upgrade`,
`pihole -up`, `pihole -g` und den vollständigen Systemcheck aus. Es gibt weder
`autoremove` noch einen automatischen Neustart.

Aktuelle und historische Zustände liegen atomar in
`/var/lib/pihole-suite/jobs/`. Sie enthalten nur strukturierte Statusfelder,
keine Befehlsausgaben, Domains, Clients, Zugangsdaten oder Browserdaten.

## Sicherheitsgrenze

Der FastAPI-Prozess läuft als `pihole-suite`, nicht als root. Er darf nur diese
drei festen Befehle per passwortlosem sudo auslösen:

```text
/usr/bin/systemctl start --no-block pihole-maintenance-check.service
/usr/bin/systemctl start --no-block pihole-maintenance-backup.service
/usr/bin/systemctl start --no-block pihole-maintenance-update.service
```

Alle Root-Jobs teilen eine Sperre. Ein gleichzeitiger zweiter Start wird über
die Web-API mit `409` abgewiesen. Web-Restore, Download und Löschen von Backups
sind absichtlich nicht vorhanden.

## Prüfung und Rollback

Nach der Installation müssen mindestens diese Nachweise erfolgreich sein:

```bash
sudo systemctl is-active --quiet pihole-FTL unbound pihole-suite caddy
sudo ss -ltnp | grep -F '127.0.0.1:8090'
sudo ss -ltnp | grep -F ':8443'
dig +short @127.0.0.1 example.com
dig +short @127.0.0.1 -p 5335 example.com
```

Der Installer erzeugt vor dem ersten Austausch der Suite-Dateien ein
root-eigenes Deployment-Backup unter `/var/backups/pihole-suite-deploy/`.
Ein bestehendes Python-Environment wird dabei nie als root ausgeführt, sondern
in einem neuen root-eigenen Environment aufgebaut und erst nach erfolgreicher
Abhängigkeitsinstallation übernommen. Für einen Rollback zuerst den
konkreten Sicherungsordner ermitteln und dann genau diesen wiederherstellen:

```bash
sudo find /var/backups/pihole-suite-deploy -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
sudo /usr/local/sbin/pihole-maintenance-web-rollback --backup-dir /var/backups/pihole-suite-deploy/PLATZHALTER_BACKUP_NAME
```

`PLATZHALTER_BACKUP_NAME` ist durch den tatsächlich angezeigten Sicherungsordner zu ersetzen. Der
Rollback akzeptiert nur direkte, nicht verlinkte Unterordner dieses Wurzelpfads,
prüft Manifest, Prüfsummen, Eigentümer und Modi vor der Wiederherstellung und
berührt keine regulären Wartungsbackups unter `/var/backups/pihole-suite/`.

Die Caddy-Installationsschritte folgen der offiziellen
[Caddy-Dokumentation](https://caddyserver.com/docs/install).
