# Gear Up!

Incremental-Spiel mit leichtem Aufbau-Anteil: vom Hinterhof-Schrauber über Radladen und eigene Radmarke bis zum weltweit führenden WorldTour-Team. Hobbyprojekt für Android, gebaut mit Godot 4.5.

Das Game Design Document liegt als Claude-Doc: *Gear Up! – GDD v0.1*.

## Stand: Phase 1 „Schrauber“ und Phase 2 „Radladen“ spielbar

- **Werkstatt:** Auftragsliste mit drei Angeboten (schnell = mehr Ruf, lukrativ = mehr Geld, knifflig = Know-how), Aufträge per Tipp abarbeiten.
- **Kundschaft:** Mehr Ruf bringt bessere Kundschaft – größere Aufträge, mehr Lohn (Laufkundschaft → Nachbarschaft → Pendler → Rennradler).
- **Ausbau:** Werkzeugkiste, Lehrling, Ersatzteilregal, Montageständer.
- **Lehrling:** erledigt schnelle Aufträge automatisch, offline mit halber Kraft (zeitlich unbegrenzt).
- **Know-how-Baum:** Ast „Werkstatt“ (Routine, Spürnase, Meisterhand); die anderen Äste sind als gesperrt sichtbar.
- **Legende/Prestige:** Legende = 0,02 · √(Gesamtgeld des Runs), +5 % auf Geld und Ruf je Punkt.
- **Phasenziel 1:** „Radladen eröffnen“ (300 Ruf, 50.000 € Miete).
- **Radladen (Phase 2):** Kundschaft kommt in den Laden und wünscht sich ein Rad; „Verkaufen!“ bedient sie, der Verkäufer automatisch (offline mit halber Kraft). Sortiment aus fünf Rädern (Citybike bis E-Bike, per Ruf freigeschaltet) mit automatischer Nachbestellung; ungeduldige Kundschaft geht wieder.
- **Ausbau Phase 2:** Verkäufer, Lager, Verkaufsfläche, Probefahrtstrecke, Bikefitting, Werkstattplätze, Zweite Filiale.
- **Phasenziel 2:** „Ersten eigenen Rahmen bauen“ (1.500 Ruf, 250.000 €, 150 Know-how); Phase 3 folgt.
- **Technik:** eigener Big-Number-Typ, Autosave alle 30 s, Export/Import als Text, Flat-UI im Hochformat.

## Projekt öffnen

1. [Godot 4.5](https://godotengine.org/download) installieren.
2. Im Projektmanager `project.godot` importieren und starten (F5).

Am Desktop öffnet sich ein Fenster im Handy-Format (450 × 800, intern 720 × 1280).

## Tests und Werkzeuge

```bash
# Alle Tests plus kurzer Start der Hauptszene (headless)
tools/run_tests.sh /pfad/zu/godot

# Balancing-Simulation: spielt Phase 1 mit 0,5 / 2 / 4 Tipps pro Sekunde durch
godot --headless --path . -s res://tools/simulate.gd

# Screenshots aller Seiten (braucht ein Display, z. B. xvfb-run)
godot --path . --resolution 720x1280 res://tools/screenshot.tscn -- --out=/tmp/shots
```

Die Tests laufen auch in GitHub Actions bei jedem Push.

Simulierte Zeit (Bot, Median): Phase-1-Ziel bei 4 / 2 / 0,5 Tipps/s nach ≈ 14 / 25 / 60 min, Phase-2-Ziel nach ≈ 41 / 60 / 106 min.

## Aufbau

| Pfad | Inhalt |
| --- | --- |
| `scripts/core/` | Spiellogik ohne Szenenbaum: `GameModel`, `BigNumber`, `NumberFormat`, `SaveCodec` |
| `scripts/data/balance.gd` | Alle Balancing-Zahlen an einer Stelle |
| `scripts/autoload/game.gd` | Autoload `Game`: Tick, Autosave, Offline-Fortschritt, Export/Import |
| `scripts/ui/` | Oberfläche, komplett im Code aufgebaut (Theme, Seiten, Dialoge) |
| `tests/` | Testrunner und Tests |
| `tools/` | Balancing-Bot, Simulation, Screenshot-Szene, Testskript |

## Android-Export

Das Exportprofil „Android“ liegt in `export_presets.cfg` (Paket `de.krinninger.gearup`, arm64 + armv7, ohne Gradle). Voraussetzungen: Exportvorlagen 4.5.1, Android SDK (build-tools, platform 35), JDK 17+ und ein Keystore, eingetragen unter *Editor → Editoreinstellungen → Export → Android* ([Godot-Doku](https://docs.godotengine.org/de/4.x/tutorials/export/exporting_for_android.html)).

```bash
godot --headless --path . --export-debug "Android" export/GearUp.apk
```

Die Debug-APK lässt sich direkt aufs Handy laden („Installation aus unbekannten Quellen“ erlauben). Für den Play Store braucht es später einen eigenen Release-Keystore.

## Nächste Meilensteine

1. **Phase 3 – Radmarke:** eigene Modelle, Forschungsbaum, Know-how-Äste Technik und Fertigung, Legende-Perk-Baum.
2. **Reparatur-Minispiel** für knifflige Fälle (Ablauf noch offen im GDD).
3. Phasen 4–6 (Märkte), danach der Team-Teil (Phasen 7–13).
