# Gear Up!

Incremental-Spiel mit leichtem Aufbau-Anteil: vom Hinterhof-Schrauber über Radladen und eigene Radmarke bis zum weltweit führenden WorldTour-Team. Hobbyprojekt für Android, gebaut mit Godot 4.5.

Das Game Design Document liegt als Claude-Doc: *Gear Up! – GDD v0.1*.

## Stand: Meilenstein 1 – Fundament + Phase 1 „Schrauber“

- **Werkstatt:** Auftragsliste mit drei Angeboten (schnell = mehr Ruf, lukrativ = mehr Geld, knifflig = Know-how), Aufträge per Tipp abarbeiten.
- **Kundschaft:** Mehr Ruf bringt bessere Kundschaft – größere Aufträge, mehr Lohn (Laufkundschaft → Nachbarschaft → Pendler → Rennradler).
- **Ausbau:** Werkzeugkiste, Lehrling, Ersatzteilregal, Montageständer.
- **Lehrling:** erledigt schnelle Aufträge automatisch, offline mit halber Kraft (zeitlich unbegrenzt).
- **Know-how-Baum:** Ast „Werkstatt“ (Routine, Spürnase, Meisterhand); die anderen Äste sind als gesperrt sichtbar.
- **Legende/Prestige:** Legende = 0,02 · √(Gesamtgeld des Runs), +5 % auf Geld und Ruf je Punkt.
- **Phasenziel:** Fortschritt Richtung „Radladen eröffnen“ (300 Ruf, 50.000 €); Phase 2 folgt in Meilenstein 2.
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

Simulierte Zeit bis zum Phase-1-Ziel (Median aus 3 Läufen): 4 Tipps/s ≈ 14 min, 2 Tipps/s ≈ 25 min, 0,5 Tipps/s ≈ 61 min.

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

Im Editor unter *Editor → Exportvorlagen verwalten* die Vorlagen für 4.5 laden, dann *Projekt → Exportieren → Android* anlegen (Android SDK und Debug-Keystore laut [Godot-Doku](https://docs.godotengine.org/de/4.x/tutorials/export/exporting_for_android.html)). Das Projekt nutzt den Compatibility-Renderer und Hochformat.

## Nächste Meilensteine

1. **Phase 2 – Radladen:** Räder einkaufen und mit Marge verkaufen, Verkaufsfläche, Werkstattplätze, Lager, Personal.
2. **Phase 3 – Radmarke:** eigene Modelle, Forschungsbaum, Know-how-Äste Technik und Fertigung, Legende-Perk-Baum.
3. **Reparatur-Minispiel** für knifflige Fälle (Ablauf noch offen im GDD).
4. Phasen 4–6 (Märkte), danach der Team-Teil (Phasen 7–13).
