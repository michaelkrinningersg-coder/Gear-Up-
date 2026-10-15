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
	# --- Phase 3: Radmarke ---
	"design_office": {
		"name": "Konstruktionsbüro", "phase": 3,
		"desc": "Ingenieure entwickeln neue Modelle auch ohne dich weiter.",
		"value": 25.0, "base_cost": 40000.0, "growth": 1.6,
		"effect": "%s Entwicklung/s (ohne Boni)", "effect_scale": 1.0,
	},
	"factory": {
		"name": "Fertigung", "phase": 3,
		"desc": "Erst Zulieferer, dann die eigene Halle: mehr Räder pro Sekunde.",
		"value": 0.6, "base_cost": 30000.0, "growth": 1.45,
		"effect": "+%s Räder/s", "effect_scale": 1.0,
	},
	"dealers": {
		"name": "Händlernetz", "phase": 3, "max_level": 8,
		"desc": "Mehr Fachhändler im Land führen deine Räder.",
		"value": 0.1, "base_cost": 50000.0, "growth": 1.8,
		"effect": "+%s %% Reichweite", "effect_scale": 100.0,
	},
	"test_lab": {
		"name": "Testlabor", "phase": 3,
		"desc": "Prüfstände und Dauertests: bessere Qualität aller Modelle.",
		"value": 0.1, "base_cost": 80000.0, "growth": 1.75,
		"effect": "+%s %% Qualität", "effect_scale": 100.0,
	},
	# --- Phase 4: National ---
	"distribution_center": {
		"name": "Vertriebszentrum", "phase": 4,
		"desc": "Schnellere Lieferung an alle Händler: mehr Nachfrage in jeder Region.",
		"value": 0.15, "base_cost": 1500000.0, "growth": 1.7,
		"effect": "+%s %% Nachfrage", "effect_scale": 100.0,
	},
	"marketing_dept": {
		"name": "Marketingabteilung", "phase": 4, "max_level": 10,
		"desc": "Profis für Kampagnen: stärkere und längere Kampagnen.",
		"value": 0.2, "base_cost": 1000000.0, "growth": 1.8,
		"effect": "+%s %% Kampagnenwirkung und -dauer", "effect_scale": 100.0,
	},
	"mass_production": {
		"name": "Großserienfertigung", "phase": 4,
		"desc": "Fließband im großen Stil: deutlich mehr Produktion.",
		"value": 0.4, "base_cost": 2000000.0, "growth": 1.75,
		"effect": "+%s %% Produktion", "effect_scale": 100.0,
	},
}

# --- National (Phase 4) -----------------------------------------------------

## Regionen des Heimatlands. size skaliert die Märkte der Sparten,
## prefs sind Spartenvorlieben (fehlend = 1). Die Heimatregion ist der Markt aus Phase 3.
const REGIONS := [
	{"id": "home", "name": "Heimatregion", "size": 1.0, "prefs": {}, "open_cost": 0.0},
	{"id": "north", "name": "Norden", "size": 0.8, "prefs": {"trekking": 1.6, "city": 1.3, "mtb": 0.5}, "open_cost": 1000000.0},
	{"id": "west", "name": "Rhein & Ruhr", "size": 1.2, "prefs": {"city": 1.4, "ebike": 1.4, "road": 0.8}, "open_cost": 2500000.0},
	{"id": "south", "name": "Bayern & Alpen", "size": 1.0, "prefs": {"mtb": 1.9, "road": 1.3, "city": 0.7}, "open_cost": 4000000.0},
	{"id": "east", "name": "Osten & Berlin", "size": 0.9, "prefs": {"city": 1.5, "road": 1.4, "mtb": 0.6}, "open_cost": 6000000.0},
	{"id": "southwest", "name": "Südwesten", "size": 0.7, "prefs": {"ebike": 1.7, "mtb": 1.4, "city": 0.6}, "open_cost": 8000000.0},
]
## Kampagne: Kosten = Grundkosten · Regionsgröße; erhöht die Attraktivität in der Region.
const CAMPAIGN_BASE_COST := 400000.0
const CAMPAIGN_DURATION := 120.0
const CAMPAIGN_EFFECT := 0.6
const CAMPAIGN_SLOTS := 2

# --- Radmarke (Phase 3) -----------------------------------------------------

## Sparten der eigenen Marke. market = Räder/s im Heimatmarkt,
## competitor = Stärke der fiktiven Konkurrenz (Qualitätspunkte).
const SPARTEN := [
	{"id": "city", "name": "Citybike", "price": 420.0, "market": 30.0, "competitor": 6.0, "dev_cost": 20000.0, "dev_work": 2500.0},
	{"id": "trekking", "name": "Trekkingrad", "price": 700.0, "market": 25.0, "competitor": 6.0, "dev_cost": 35000.0, "dev_work": 3500.0},
	{"id": "mtb", "name": "Mountainbike", "price": 1200.0, "market": 20.0, "competitor": 7.0, "dev_cost": 60000.0, "dev_work": 5000.0},
	{"id": "road", "name": "Rennrad", "price": 2000.0, "market": 15.0, "competitor": 8.0, "dev_cost": 100000.0, "dev_work": 7000.0},
	{"id": "ebike", "name": "E-Bike", "price": 3200.0, "market": 25.0, "competitor": 8.0, "dev_cost": 150000.0, "dev_work": 9000.0, "requires": "e_drive"},
]
## Generation = Rahmenmaterial; die Obergrenze setzt der Know-how-Knoten „Rahmenmaterial".
const MATERIALS := ["Stahl", "Alu", "Carbon", "Titan"]
const GEN_COST_GROWTH := 4.0
const GEN_WORK_GROWTH := 3.0
const GEN_PRICE_BONUS := 0.25
## Baukasten: Preisklasse bestimmt Preis, Attraktivität und Stückkosten (Anteil am Preis).
const PRICE_CLASSES := [
	{"name": "Einsteiger", "price": 0.75, "appeal": 1.35, "cost": 0.72},
	{"name": "Mittelklasse", "price": 1.0, "appeal": 1.0, "cost": 0.65},
	{"name": "Premium", "price": 1.5, "appeal": 0.7, "cost": 0.58},
]
const DEFAULT_PRICE_CLASS := 1
const BRAND_BASE_PRODUCTION := 1.0
const BRAND_BASE_REACH := 0.25
const BRAND_REP_PER_BIKE := 0.3
## Know-how aus jeder fertigen Modellgeneration (× Generation).
const DEV_KNOWHOW := 15.0
const BRAND_COMPETITORS := ["Velonord", "Rheinrad", "Alpenwerk", "Kettenblatt & Söhne"]

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
	"frame_material": {
		"name": "Rahmenmaterial", "branch": "tech", "max_level": 3,
		"desc": "Alu, Carbon, Titan: jede Stufe erlaubt eine weitere Modellgeneration.",
		"value": 1.0, "base_cost": 20.0, "growth": 3.0,
		"effect": "+%s Generationen", "effect_scale": 1.0,
	},
	"aero": {
		"name": "Aerodynamik", "branch": "tech", "max_level": 5,
		"desc": "Windschnittige Rahmen: mehr Qualität für alle Modelle.",
		"value": 0.1, "base_cost": 10.0, "growth": 1.8,
		"effect": "+%s %% Qualität", "effect_scale": 100.0,
	},
	"e_drive": {
		"name": "E-Antrieb", "branch": "tech", "max_level": 1,
		"desc": "Schaltet die Sparte E-Bike frei.",
		"value": 1.0, "base_cost": 40.0, "growth": 1.0,
		"effect": "E-Bikes entwickelbar", "effect_scale": 1.0,
	},
	"e_shifting": {
		"name": "Elektronische Schaltung", "branch": "tech", "max_level": 5,
		"desc": "Hightech-Ausstattung: höherer Verkaufspreis.",
		"value": 0.08, "base_cost": 15.0, "growth": 1.9,
		"effect": "+%s %% Verkaufspreis Marke", "effect_scale": 100.0,
	},
	"unit_cost": {
		"name": "Stückkosten", "branch": "production", "max_level": 5,
		"desc": "Bessere Einkaufskonditionen und weniger Verschnitt.",
		"value": 0.06, "base_cost": 8.0, "growth": 1.8,
		"effect": "−%s %% Stückkosten", "effect_scale": 100.0,
	},
	"quality_spread": {
		"name": "Qualitätsstreuung", "branch": "production", "max_level": 5,
		"desc": "Gleichmäßigere Fertigung: mehr Qualität.",
		"value": 0.08, "base_cost": 10.0, "growth": 1.8,
		"effect": "+%s %% Qualität", "effect_scale": 100.0,
	},
	"automation": {
		"name": "Automatisierung", "branch": "production", "max_level": 10,
		"desc": "Roboter am Band: mehr Produktion.",
		"value": 0.2, "base_cost": 12.0, "growth": 1.7,
		"effect": "+%s %% Produktion", "effect_scale": 100.0,
	},
	"second_plant": {
		"name": "Zweites Werk", "branch": "production", "max_level": 1,
		"desc": "Ein zweites Werk verdoppelt die Produktion.",
		"value": 1.0, "base_cost": 80.0, "growth": 1.0,
		"effect": "+%s %% Produktion", "effect_scale": 100.0,
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
	{
		"name": "Radmarke", "playable": true,
		"goal_title": "Marktführer im Heimatland werden",
		"goal_rep": 0.0, "goal_money": 3000000.0, "goal_share": 0.25,
	},
	{
		"name": "National", "playable": true,
		"goal_title": "Nummer 1 im ganzen Land",
		"goal_rep": 0.0, "goal_money": 20000000.0, "goal_share": 0.2,
	},
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


static func region(id: String) -> Dictionary:
	for r in REGIONS:
		if r["id"] == id:
			return r
	return {}


static func sparte(id: String) -> Dictionary:
	for s in SPARTEN:
		if s["id"] == id:
			return s
	return {}


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
