Basierend auf den Informationen aus dem Pi.Alert GitHub-Repository, hier ist eine überarbeitete Anleitung zur Installation von Pi.Alert für einen IP-Bereich und optional für zwei IP-Bereiche:

---

# Pi-hole & Pi.Alert Installation auf Raspberry Pi

## Pi-hole & Pi.Alert: Das ultimative Netzwerk-Toolset!

Mit dieser Anleitung können Sie Pi-hole und Pi.Alert auf einem Raspberry Pi installieren und so in die Welt der Netzwerküberwachung und Werbeblockierung eintauchen.

### Voraussetzungen:
- Raspberry Pi mit Debian OS (64-Bit) mit Kernel-Version 6.1.47-v8+.
- Aktive Internetverbindung.

### Schritt 1: Installation von Pi-hole

1. Aktualisieren Sie Ihr System:
```bash
sudo apt update && sudo apt upgrade -y
```

2. Pi-hole installieren:
```bash
curl -sSL https://install.pi-hole.net | bash
```

3. Befolgen Sie die Anweisungen auf dem Bildschirm, um Pi-hole zu konfigurieren.

### Schritt 2: Installation von Pi.Alert

1. Laden Sie das Pi.Alert-Installationsskript herunter:
```bash
bash -c "$(wget -qLO - https://github.com/leiweibau/Pi.Alert/raw/main/install/pialert_install.sh)"
```

2. Befolgen Sie die Anweisungen auf dem Bildschirm, um Pi.Alert zu konfigurieren.

### Schritt 3: Konfigurieren von Pi.Alert für die Überwachung eines Netzwerks

1. Bearbeiten Sie die Pi.Alert-Konfigurationsdatei:
```bash
nano /home/pi/pialert/config.php
```

2. Suchen Sie den Abschnitt SCAN_SUBNETS und fügen Sie das gewünschte Netzwerk hinzu:
```bash
SCAN_SUBNETS = [ '192.168.0.1/24' ]
```

3. Speichern Sie die Datei und verlassen Sie den Editor.

### Optional: Konfigurieren von Pi.Alert für die Überwachung zweier Netzwerke

1. Bearbeiten Sie die Pi.Alert-Konfigurationsdatei:
```bash
nano /home/pi/pialert/config.php
```

2. Suchen Sie den Abschnitt SCAN_SUBNETS und fügen Sie die gewünschten Netzwerke hinzu:
```bash
SCAN_SUBNETS = [ '192.168.0.1/24', '192.168.178.0/24' ]
```
