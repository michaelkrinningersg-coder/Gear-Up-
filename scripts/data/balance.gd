class_name Balance
extends RefCounted
## Alle Balancing-Zahlen an einer Stelle. Werte sind erste Annahmen und werden
## mit tools/simulate.gd nachgestellt (siehe „Offene Punkte" im GDD).

# --- Allgemein ---------------------------------------------------------------

const START_MONEY := 0.0
const AUTOSAVE_SECONDS := 30.0
## Gedämpfter Offline-Fortschritt: Anteil der Online-Rate, zeitlich unbegrenzt.
const OFFLINE_RATE := 0.5
## Kürzere Abwesenheiten werden still verrechnet, ohne Willkommen-Dialog.
const OFFLINE_REPORT_MIN_SECONDS := 60.0

# --- Legende / Prestige ------------------------------------------------------

## Legende = k · √(Gesamtgeld des Runs)
const LEGEND_K := 0.02
## Grundmultiplikator: jeder Legende-Punkt bringt diesen Anteil auf Geld und Ruf.
const LEGEND_BONUS_PER_POINT := 0.05

# --- Werkstatt (Phase 1) -----------------------------------------------------

const BOARD_SIZE := 3
const BASE_TAP_WORK := 1.0
const ORDER_VARIANCE := 0.15
const TRICKY_BASE_CHANCE := 0.2
const TRICKY_MAX_CHANCE := 0.6

const KIND_NAMES := {
	"quick": "Schnell",
	"lucrative": "Lukrativ",
	"tricky": "Knifflig",
}

## Schnelle Aufträge bringen mehr Ruf pro Arbeit, lukrative mehr Geld,
## knifflige zusätzlich Know-how.
const ORDER_TEMPLATES := [
	{"id": "flat_tire", "name": "Platten flicken", "kind": "quick", "work": 8.0, "money": 4.0, "rep": 1.0},
	{"id": "chain_care", "name": "Kette reinigen & ölen", "kind": "quick", "work": 10.0, "money": 5.0, "rep": 1.0},
	{"id": "brake_pads", "name": "Bremsbeläge tauschen", "kind": "quick", "work": 14.0, "money": 7.0, "rep": 1.0},
	{"id": "wheel_true", "name": "Laufrad zentrieren", "kind": "lucrative", "work": 32.0, "money": 22.0, "rep": 2.0},
	{"id": "brake_bleed", "name": "Bremse entlüften", "kind": "lucrative", "work": 38.0, "money": 27.0, "rep": 2.0},
	{"id": "inspection", "name": "Große Inspektion", "kind": "lucrative", "work": 45.0, "money": 33.0, "rep": 3.0},
	{"id": "creak", "name": "Knarzen aufspüren", "kind": "tricky", "work": 28.0, "money": 14.0, "rep": 2.0, "knowhow": 1.0},
	{"id": "shifting", "name": "Schaltung spinnt", "kind": "tricky", "work": 36.0, "money": 19.0, "rep": 2.0, "knowhow": 1.0},
]

## Mehr Ruf lockt bessere Kundschaft an: größere Aufträge, mehr Lohn.
const CUSTOMER_TIERS := [
	{"name": "Laufkundschaft", "rep": 0.0},
	{"name": "Nachbarschaft", "rep": 30.0},
	{"name": "Pendler", "rep": 100.0},
	{"name": "Rennradler", "rep": 220.0},
	{"name": "Vereinsfahrer", "rep": 900.0},
]
const TIER_WORK_FACTOR := 3.0
const TIER_MONEY_FACTOR := 3.3
const TIER_REP_FACTOR := 1.3

## Ausbaustufen. Kosten = base_cost · growth^Stufe; Effekt je Stufe = value.
## effect: Formatstring für den Gesamteffekt (Stufe · value · effect_scale).
const UPGRADES := {
	"toolbox": {
		"name": "Werkzeugkiste", "phase": 1,
		"desc": "Besseres Werkzeug: mehr Arbeit pro Tipp.",
		"value": 1.0, "base_cost": 12.0, "growth": 1.5,
		"effect": "+%s Arbeit pro Tipp", "effect_scale": 1.0,
	},
	"apprentice": {
		"name": "Lehrling", "phase": 1, "requires_rep": 8.0,
		"desc": "Erledigt schnelle Aufträge automatisch – auch offline mit halber Kraft.",
		"value": 1.5, "base_cost": 40.0, "growth": 1.55,
		"effect": "%s Arbeit/s (ohne Boni)", "effect_scale": 1.0,
	},
	"parts_shelf": {
		"name": "Ersatzteilregal", "phase": 1,
		"desc": "Teile auf Lager statt Laufwege: mehr Erlös pro Auftrag.",
		"value": 0.15, "base_cost": 80.0, "growth": 1.8,
		"effect": "+%s %% Erlös", "effect_scale": 100.0,
	},
	"repair_stand": {
		"name": "Montageständer", "phase": 1, "max_level": 10,
		"desc": "Rad auf Arbeitshöhe: schneller arbeiten, für dich und den Lehrling.",
		"value": 0.2, "base_cost": 200.0, "growth": 2.3,
		"effect": "+%s %% Arbeitstempo", "effect_scale": 100.0,
	},
	# --- Phase 2: Radladen ---
	"salesperson": {
		"name": "Verkäufer", "phase": 2,
		"desc": "Bedient wartende Kundschaft automatisch – auch offline mit halber Kraft.",
		"value": 0.15, "base_cost": 3000.0, "growth": 1.55,
		"effect": "%s Verkäufe/s", "effect_scale": 1.0,
	},
	"storage": {
		"name": "Lager", "phase": 2,
		"desc": "Mehr Stellplätze für Räder auf Vorrat.",
		"value": 3.0, "base_cost": 2000.0, "growth": 1.6,
		"effect": "+%s Stellplätze", "effect_scale": 1.0,
	},
	"sales_floor": {
		"name": "Verkaufsfläche", "phase": 2,
		"desc": "Größerer Laden: mehr Kundschaft kommt herein.",
		"value": 0.25, "base_cost": 4000.0, "growth": 1.7,
		"effect": "+%s %% Kundschaft", "effect_scale": 100.0,
	},
	"test_track": {
		"name": "Probefahrtstrecke", "phase": 2, "max_level": 10,
		"desc": "Wer Probe fährt, erzählt davon: mehr Ruf pro verkauftem Rad.",
		"value": 0.2, "base_cost": 8000.0, "growth": 1.9,
		"effect": "+%s %% Ruf pro Verkauf", "effect_scale": 100.0,
	},
	"bikefitting": {
		"name": "Bikefitting", "phase": 2, "max_level": 10,
		"desc": "Rad perfekt eingestellt: Kundschaft zahlt mehr.",
		"value": 0.08, "base_cost": 12000.0, "growth": 1.9,
		"effect": "+%s %% Verkaufspreis", "effect_scale": 100.0,
	},
	"workbenches": {
		"name": "Werkstattplätze", "phase": 2,
		"desc": "Mehr Plätze für Mechaniker: der Lehrling bekommt Verstärkung.",
		"value": 0.5, "base_cost": 6000.0, "growth": 1.8,
		"effect": "+%s %% Lehrling-Tempo", "effect_scale": 100.0,
	},
	"second_store": {
		"name": "Zweite Filiale", "phase": 2, "max_level": 1,
		"desc": "Ein zweiter Laden in der Nachbarstadt verdoppelt die Kundschaft.",
		"value": 1.0, "base_cost": 150000.0, "growth": 1.0,
		"effect": "+%s %% Kundschaft", "effect_scale": 100.0,
	},
}

# --- Radladen (Phase 2) ------------------------------------------------------

## Kundschaft pro Sekunde ohne Boni; steigt mit dem Ruf (√-gedämpft).
const SHOP_BASE_CUSTOMERS := 0.12
const SHOP_REP_CUSTOMER_FACTOR := 0.03
const SHOP_BASE_CAPACITY := 4
const SHOP_QUEUE_MAX := 4
## Sekunden, die Kundschaft wartet, bevor sie wieder geht.
const SHOP_PATIENCE := 25.0

## Räder im Sortiment. Kundschaft wünscht sich ein freigeschaltetes Modell
## nach Gewicht; Know-how kommt aus dem Feedback zu anspruchsvollen Rädern.
const BIKES := [
	{"id": "city", "name": "Citybike", "buy": 180.0, "sell": 270.0, "rep": 2.0, "knowhow": 0.0, "requires_rep": 0.0, "weight": 4.0},
	{"id": "trekking", "name": "Trekkingrad", "buy": 340.0, "sell": 520.0, "rep": 3.0, "knowhow": 0.0, "requires_rep": 350.0, "weight": 3.0},
	{"id": "mtb", "name": "Mountainbike", "buy": 650.0, "sell": 1000.0, "rep": 4.0, "knowhow": 0.1, "requires_rep": 600.0, "weight": 3.0},
	{"id": "road", "name": "Rennrad", "buy": 1200.0, "sell": 1900.0, "rep": 6.0, "knowhow": 0.25, "requires_rep": 1000.0, "weight": 2.0},
	{"id": "ebike", "name": "E-Bike", "buy": 2100.0, "sell": 3300.0, "rep": 8.0, "knowhow": 0.4, "requires_rep": 1400.0, "weight": 2.0},
]

const KNOWHOW_BRANCHES := [
	{"id": "workshop", "name": "Werkstatt", "phase": 1, "desc": "Schnellere Reparaturen, mehr knifflige Fälle, höhere Belohnung."},
	{"id": "tech", "name": "Technik", "phase": 3, "desc": "Rahmenmaterial Stahl bis Titan, Aero, E-Antrieb, elektronische Schaltung."},
	{"id": "production", "name": "Fertigung", "phase": 3, "desc": "Stückkosten, Qualitätsstreuung, Automatisierung, zweites Werk."},
	{"id": "sport", "name": "Sport", "phase": 7, "desc": "Teammaterial, Windkanal, Leistungsdiagnostik."},
]

## Know-how-Knoten; Kosten in Know-how, Formel wie bei UPGRADES.
const KNOWHOW_NODES := {
	"routine": {
		"name": "Routine", "branch": "workshop", "max_level": 10,
		"desc": "Handgriffe sitzen: mehr Arbeit pro Tipp.",
		"value": 0.1, "base_cost": 2.0, "growth": 1.7,
		"effect": "+%s %% Arbeit pro Tipp", "effect_scale": 100.0,
	},
	"keen_eye": {
		"name": "Spürnase", "branch": "workshop", "max_level": 5,
		"desc": "Knifflige Fälle landen häufiger auf deiner Liste.",
		"value": 0.08, "base_cost": 3.0, "growth": 1.9,
		"effect": "+%s %% Chance auf knifflige Fälle", "effect_scale": 100.0,
	},
	"master_hand": {
		"name": "Meisterhand", "branch": "workshop", "max_level": 5,
		"desc": "Mehr Know-how aus jedem kniffligen Fall.",
		"value": 1.0, "base_cost": 5.0, "growth": 2.2,
		"effect": "+%s Know-how pro kniffligem Fall", "effect_scale": 1.0,
	},
}

## Phasenleiter. goal_* gelten für den Aufstieg aus dieser Phase.
## playable = Inhalte der Phase sind umgesetzt.
const PHASES := [
	{
		"name": "Schrauber", "playable": true,
		"goal_title": "Radladen eröffnen",
		"goal_rep": 300.0, "goal_money": 50000.0,
	},
	{
		"name": "Radladen", "playable": true,
		"goal_title": "Ersten eigenen Rahmen bauen",
		"goal_rep": 1500.0, "goal_money": 250000.0, "goal_knowhow": 150.0,
	},
	{"name": "Radmarke", "playable": false, "goal_title": "Marktanteil Heimatland", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "National", "playable": false, "goal_title": "Marktanteil Inland", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "Europa", "playable": false, "goal_title": "Präsenz in Europa", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "International", "playable": false, "goal_title": "Continental-Lizenz", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "Continental-Team", "playable": false, "goal_title": "ProTeam-Lizenz", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "ProTeam", "playable": false, "goal_title": "WorldTour-Lizenz", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "WorldTour unteres Drittel", "playable": false, "goal_title": "Mittelfeld", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "WorldTour Mittelfeld", "playable": false, "goal_title": "Top 5", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "Top 5", "playable": false, "goal_title": "Top 3", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "Top 3", "playable": false, "goal_title": "Platz 1", "goal_rep": 0.0, "goal_money": 0.0},
	{"name": "Nr. 1", "playable": false, "goal_title": "Dominanz halten", "goal_rep": 0.0, "goal_money": 0.0},
]

static var _templates_by_id := {}
static var _templates_by_kind := {}


static func bike(id: String) -> Dictionary:
	for b in BIKES:
		if b["id"] == id:
			return b
	return {}


static func order_template(id: String) -> Dictionary:
	_index_templates()
	return _templates_by_id.get(id, {})


static func templates_of_kind(kind: String) -> Array:
	_index_templates()
	return _templates_by_kind.get(kind, [])


static func customer_tier_for(reputation: float) -> int:
	var tier := 0
	for i in CUSTOMER_TIERS.size():
		if reputation >= float(CUSTOMER_TIERS[i]["rep"]):
			tier = i
	return tier


static func phase_def(phase: int) -> Dictionary:
	return PHASES[clampi(phase - 1, 0, PHASES.size() - 1)]


static func is_phase_playable(phase: int) -> bool:
	return phase >= 1 and phase <= PHASES.size() and bool(PHASES[phase - 1]["playable"])


static func branch_def(id: String) -> Dictionary:
	for branch in KNOWHOW_BRANCHES:
		if branch["id"] == id:
			return branch
	return {}


static func _index_templates() -> void:
	if not _templates_by_id.is_empty():
		return
	for tpl in ORDER_TEMPLATES:
		_templates_by_id[tpl["id"]] = tpl
		if not _templates_by_kind.has(tpl["kind"]):
			_templates_by_kind[tpl["kind"]] = []
		_templates_by_kind[tpl["kind"]].append(tpl)
