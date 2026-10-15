# Gear Up! – Hinweise für Claude

- Godot 4.5, GDScript, Zielplattform Android (Hochformat, Compatibility-Renderer).
- Sprache: Bezeichner auf Englisch, Kommentare und UI-Texte auf Deutsch.
- Einrückung mit Tabs, statische Typen wo möglich.
- Spiellogik gehört in `scripts/core/` (ohne Szenenbaum, testbar), Zahlen in `scripts/data/balance.gd`, Oberfläche in `scripts/ui/` (im Code gebaut).
- Geld, Ruf, Know-how und Legende sind `BigNumber` (unveränderlich, jede Operation liefert ein neues Objekt).
- Vor dem Commit: `tools/run_tests.sh <godot>`; nach Balancing-Änderungen `tools/simulate.gd` laufen lassen und den Korridor in `tests/test_balance.gd` prüfen.
- Nach neuen Skripten oder Assets einmal `godot --headless --path . --import` ausführen und die erzeugten `.uid`/`.import`-Dateien mit committen.
