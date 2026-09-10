# Wartungs-Flugplan

## Oberfläche

Lokaler Betriebsarbeitsplatz, kein Marketing-Dashboard. Eine breite linke Zone zeigt den letzten Auftrag, reale Systemwerte und die Prüfliste. Rechts stehen drei getrennte Wartungsaktionen. Unter 720 px folgt eine einzelne Spalte. Backups und geschlossene JSON-Details schließen die Ansicht ab.

## Gestaltungswerte

- Systemschrift, Zeilenhöhe 1,5; Haupttitel 1,65–2,35 rem; maximal 1380 px Arbeitsbreite.
- Hintergrund `#0d1419`, Statusfläche `#151f26`, Trennlinien `#354650`.
- Primärtext `#edf3f5`, Sekundärtext `#a9bbc4`.
- Erfolg `#77e0c6`, Aufmerksamkeit `#f3c578`, Fehler `#ffaaa7` – stets zusätzlich ausgeschrieben.
- Eingabebegrenzungen `#607681`, 3,89:1 gegenüber dem Hintergrund.
- Statusfläche mit 12-px-Radius, Bedienelemente mit 6 px. Mindestens 44 px Zielhöhe, einschließlich Markenlink und Checkboxlabel.
- Sichtbarer 3-px-Fokus mit Abstand. Nur kurze Farbwechsel bei erlaubter Bewegung; keine Animation bei reduzierter Bewegung.

## Verhalten

Deutsch/Englisch aus statischen Wörterbüchern; nur `de` oder `en` werden gespeichert. Serverwerte landen ausschließlich in Textknoten. Fehlende Messwerte heißen „Nicht verfügbar“. Ein laufender Auftrag zeigt keine geschätzten Prozente; der bestehende Runner liefert die einzelnen Ergebnisse erst nach Abschluss.

Anmeldung mit dem bestehenden `SUITE_API_KEY` und Sitzungserneuerung führen ins Dashboard, Abmeldung und Ablauf zurück zum API-Key-Feld. Startende und laufende Aufträge sperren konkurrierende Aktionen. Verbindungsfehler verlangen eine manuelle Statusabfrage; kein dauerhaftes Hintergrundpolling.

## Prüfung

Browsermatrix: 1440, 1063, 390 und 320 px, DE/EN, 200-%-CSS-Zoom, echte Tab-Fokusnavigation und reduzierte Bewegung. Die Prüfbilder verwenden ausdrücklich Testdaten einschließlich fehlender optionaler Werte und eines als Text dargestellten XSS-Testhosts. Unabhängiger Review: zwei Befunde zu Feldkontrast und Markenlink-Zielhöhe behoben und bestätigt. Der zusätzliche Design-Detector lief nur im eingeschränkten Regex-Modus; keine vollständige automatische Barrierefreiheitszertifizierung. Keine Rasterbilder oder externen Assets im Produkt.
