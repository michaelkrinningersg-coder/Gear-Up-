#!/usr/bin/env bash
# Führt Import, Tests und einen kurzen Start der Hauptszene headless aus.
# Aufruf: tools/run_tests.sh [pfad/zu/godot]   (Standard: $GODOT oder „godot")
set -euo pipefail

GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."

echo "== Import =="
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== Tests =="
out=$("$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1) || status=$?
echo "$out"
if [[ "${status:-0}" -ne 0 ]] || grep -qE "SCRIPT ERROR|Parse Error" <<<"$out"; then
	echo "Tests fehlgeschlagen" >&2
	exit 1
fi

echo "== Start der Hauptszene (120 Frames) =="
out=$("$GODOT" --headless --path . --quit-after 120 2>&1) || true
if grep -qE "SCRIPT ERROR|Parse Error|ERROR:" <<<"$out"; then
	echo "$out" >&2
	echo "Fehler beim Start der Hauptszene" >&2
	exit 1
fi
echo "OK"
