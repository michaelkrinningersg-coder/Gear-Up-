class_name GameModel
extends RefCounted
## Komplette Spiellogik ohne Szenenbaum, damit sie headless testbar ist.
## Die Oberfläche liest den Zustand direkt und hört auf die Signale.

signal board_changed
signal upgrades_changed
signal order_completed(order: Dictionary, reward: Dictionary, by_apprentice: bool)
signal customer_tier_changed(tier: int)
signal sale_completed(bike_id: String, reward: Dictionary, by_staff: bool)
signal model_developed(sparte_id: String, generation: int)
signal phase_changed
signal run_reset

# --- Run-Zustand (wird beim Prestige zurückgesetzt) ----------------------------

var money: BigNumber
var reputation: BigNumber
var knowhow: BigNumber
## Gesamtgeld des Runs (nur Einnahmen) – Basis der Legende.
var run_money: BigNumber
var phase := 1
var upgrades: Dictionary = {}
var knowhow_levels: Dictionary = {}
var board: Array[Dictionary] = []
var active_order: Dictionary = {}
var active_progress := 0.0
var apprentice_order: Dictionary = {}
var apprentice_progress := 0.0
var run_time := 0.0
var run_orders := 0
# Radladen (Phase 2)
var stock: Dictionary = {}
## Modelle, die bewusst nicht nachbestellt werden (id -> true).
var shop_disabled: Dictionary = {}
var shop_queue: Array[Dictionary] = []
var shop_arrivals := 0.0
var shop_serve_progress := 0.0
var run_sales := 0
var missed_customers := 0
# Radmarke (Phase 3): Sparte -> {"gen": int, "class": int}
var brand: Dictionary = {}
## Laufende Entwicklung: {"sparte": id, "work": float} oder leer.
var dev_project: Dictionary = {}
var run_bikes_built := 0.0
# National (Phase 4)
var regions_open: Dictionary = {}
## Laufende Kampagnen: [{"region": id, "time_left": Sekunden}]
var campaigns: Array[Dictionary] = []

# --- Dauerhaft -----------------------------------------------------------------

var legend: BigNumber
var prestige_count := 0
var lifetime_money: BigNumber
var total_orders := 0
var total_taps := 0
var total_time := 0.0

var rng := RandomNumberGenerator.new()
var _last_tier := 0


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_reset_permanent()
	reset_run()


## Setzt den Run auf den Schrauber zurück. Legende und Gesamtstatistik bleiben.
func reset_run() -> void:
	money = BigNumber.of(Balance.START_MONEY)
	reputation = BigNumber.zero()
	knowhow = BigNumber.zero()
	run_money = BigNumber.zero()
	phase = 1
	upgrades = {}
	knowhow_levels = {}
	active_order = {}
	active_progress = 0.0
	apprentice_order = {}
	apprentice_progress = 0.0
	run_time = 0.0
	run_orders = 0
	stock = {}
	shop_disabled = {}
	shop_queue.clear()
	shop_arrivals = 0.0
	shop_serve_progress = 0.0
	run_sales = 0
	missed_customers = 0
	brand = {}
	dev_project = {}
	run_bikes_built = 0.0
	regions_open = {}
	campaigns.clear()
	_last_tier = customer_tier()
	board.clear()
	_fill_board()
	_emit_all()
	run_reset.emit()


## Löscht alles, auch die Legende.
func wipe() -> void:
	_reset_permanent()
	reset_run()


func _reset_permanent() -> void:
	legend = BigNumber.zero()
	lifetime_money = BigNumber.zero()
	prestige_count = 0
	total_orders = 0
	total_taps = 0
	total_time = 0.0


# --- Abgeleitete Werte ---------------------------------------------------------

func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func knowhow_level(id: String) -> int:
	return int(knowhow_levels.get(id, 0))


func legend_mult() -> float:
	return 1.0 + Balance.LEGEND_BONUS_PER_POINT * legend.to_float()


func speed_mult() -> float:
	return 1.0 + _upgrade_value("repair_stand") * upgrade_level("repair_stand")


func tap_power() -> float:
	var base := Balance.BASE_TAP_WORK + _upgrade_value("toolbox") * upgrade_level("toolbox")
	return base * (1.0 + _knowhow_value("routine") * knowhow_level("routine")) * speed_mult()


func apprentice_rate() -> float:
	var benches := 1.0 + _upgrade_value("workbenches") * upgrade_level("workbenches")
	return _upgrade_value("apprentice") * upgrade_level("apprentice") * speed_mult() * benches


func money_mult() -> float:
	return (1.0 + _upgrade_value("parts_shelf") * upgrade_level("parts_shelf")) * legend_mult()


func reputation_mult() -> float:
	return legend_mult()


func tricky_chance() -> float:
	var chance := Balance.TRICKY_BASE_CHANCE + _knowhow_value("keen_eye") * knowhow_level("keen_eye")
	return minf(chance, Balance.TRICKY_MAX_CHANCE)


func customer_tier() -> int:
	return Balance.customer_tier_for(reputation.to_float())


func _upgrade_value(id: String) -> float:
	return float(Balance.UPGRADES[id]["value"])


func _knowhow_value(id: String) -> float:
	return float(Balance.KNOWHOW_NODES[id]["value"])


# --- Aufträge ------------------------------------------------------------------

static func order_template(order: Dictionary) -> Dictionary:
	return Balance.order_template(str(order.get("tpl", "")))


func order_work(order: Dictionary) -> float:
	var tpl := order_template(order)
	return float(tpl["work"]) * float(order["var"]) * pow(Balance.TIER_WORK_FACTOR, int(order["tier"]))


## Belohnung mit den aktuellen Multiplikatoren (Upgrades mitten im Auftrag zählen also mit).
func order_reward(order: Dictionary) -> Dictionary:
	var tpl := order_template(order)
	var tier := int(order["tier"])
	var base_money := float(tpl["money"]) * float(order["var"]) * pow(Balance.TIER_MONEY_FACTOR, tier)
	var rep := roundf(float(tpl["rep"]) * pow(Balance.TIER_REP_FACTOR, tier))
	var gained_knowhow := 0.0
	if tpl["kind"] == "tricky":
		gained_knowhow = float(tpl.get("knowhow", 1.0)) + _knowhow_value("master_hand") * knowhow_level("master_hand")
	return {
		"money": BigNumber.of(base_money * money_mult()),
		"rep": BigNumber.of(rep * reputation_mult()),
		"knowhow": BigNumber.of(gained_knowhow),
	}


func accept_order(index: int) -> bool:
	if not active_order.is_empty() or index < 0 or index >= board.size():
		return false
	active_order = board[index]
	active_progress = 0.0
	board[index] = _make_order()
	board_changed.emit()
	return true


## Ein Tipp auf „Schrauben". Liefert die Belohnung, wenn der Auftrag damit fertig ist.
func tap() -> Dictionary:
	if active_order.is_empty():
		return {}
	total_taps += 1
	active_progress += tap_power()
	if active_progress < order_work(active_order):
		return {}
	var order := active_order
	active_order = {}
	active_progress = 0.0
	var reward := _complete(order, false)
	board_changed.emit()
	return reward


func tick(delta: float) -> void:
	run_time += delta
	total_time += delta
	if shop_open():
		_tick_shop(delta)
	if brand_open():
		_tick_brand(delta)
	var rate := apprentice_rate()
	if rate <= 0.0:
		return
	if apprentice_order.is_empty():
		apprentice_order = _make_order("quick")
	apprentice_progress += rate * delta
	var guard := 0
	while apprentice_progress >= order_work(apprentice_order) and guard < 1000:
		apprentice_progress -= order_work(apprentice_order)
		_complete(apprentice_order, true)
		apprentice_order = _make_order("quick")
		guard += 1


func _make_order(kind := "") -> Dictionary:
	if kind == "":
		if rng.randf() < tricky_chance():
			kind = "tricky"
		else:
			kind = "quick" if rng.randf() < 0.5 else "lucrative"
	var pool := Balance.templates_of_kind(kind)
	var tpl: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var variance := rng.randf_range(1.0 - Balance.ORDER_VARIANCE, 1.0 + Balance.ORDER_VARIANCE)
	return {"tpl": tpl["id"], "tier": customer_tier(), "var": snappedf(variance, 0.01)}


func _fill_board() -> void:
	while board.size() < Balance.BOARD_SIZE:
		board.append(_make_order())


func _complete(order: Dictionary, by_apprentice: bool) -> Dictionary:
	var reward := order_reward(order)
	_gain(reward)
	run_orders += 1
	total_orders += 1
	order_completed.emit(order, reward, by_apprentice)
	return reward


func _gain(reward: Dictionary) -> void:
	var earned: BigNumber = reward["money"]
	money = money.add(earned)
	run_money = run_money.add(earned)
	lifetime_money = lifetime_money.add(earned)
	reputation = reputation.add(reward["rep"])
	knowhow = knowhow.add(reward["knowhow"])
	var tier := customer_tier()
	if tier > _last_tier:
		_last_tier = tier
		# Die neue Kundschaft steht sofort auf der Liste
		for order in board:
			order["tier"] = tier
		customer_tier_changed.emit(tier)
		board_changed.emit()


# --- Radladen (Phase 2) --------------------------------------------------------

func shop_open() -> bool:
	return phase >= 2


func bike_unlocked(id: String) -> bool:
	return reputation.gte(BigNumber.of(Balance.bike(id)["requires_rep"]))


func in_assortment(id: String) -> bool:
	return bike_unlocked(id) and not shop_disabled.has(id)


func set_assortment(id: String, enabled: bool) -> void:
	if enabled:
		shop_disabled.erase(id)
		_restock()
	else:
		shop_disabled[id] = true


func shop_capacity() -> int:
	return Balance.SHOP_BASE_CAPACITY + int(_upgrade_value("storage") * upgrade_level("storage"))


func stock_of(id: String) -> int:
	return int(stock.get(id, 0))


func stock_total() -> int:
	var total := 0
	for id in stock:
		total += int(stock[id])
	return total


func customer_rate() -> float:
	var rep_factor := 1.0 + Balance.SHOP_REP_CUSTOMER_FACTOR * sqrt(maxf(reputation.to_float(), 0.0))
	var floor_factor := 1.0 + _upgrade_value("sales_floor") * upgrade_level("sales_floor")
	var stores := 1.0 + _upgrade_value("second_store") * upgrade_level("second_store")
	return Balance.SHOP_BASE_CUSTOMERS * rep_factor * floor_factor * stores


func salesperson_rate() -> float:
	return _upgrade_value("salesperson") * upgrade_level("salesperson")


func bike_reward(id: String) -> Dictionary:
	var b := Balance.bike(id)
	var price := 1.0 + _upgrade_value("bikefitting") * upgrade_level("bikefitting")
	var rep := 1.0 + _upgrade_value("test_track") * upgrade_level("test_track")
	return {
		"money": BigNumber.of(float(b["sell"]) * price * legend_mult()),
		"rep": BigNumber.of(float(b["rep"]) * rep * reputation_mult()),
		"knowhow": BigNumber.of(float(b["knowhow"])),
	}


## Index der ersten wartenden Person, deren Wunschrad auf Lager ist (-1 = keine).
func serviceable_customer() -> int:
	for i in shop_queue.size():
		if stock_of(shop_queue[i]["bike"]) > 0:
			return i
	return -1


## Verkauft an die erste bedienbare Person. Liefert die Belohnung oder {}.
func sell(by_staff := false) -> Dictionary:
	var index := serviceable_customer()
	if index < 0:
		return {}
	var bike_id: String = shop_queue[index]["bike"]
	shop_queue.remove_at(index)
	stock[bike_id] = stock_of(bike_id) - 1
	var reward := bike_reward(bike_id)
	_gain(reward)
	run_sales += 1
	sale_completed.emit(bike_id, reward, by_staff)
	_restock()
	return reward


func _tick_shop(delta: float) -> void:
	shop_arrivals += customer_rate() * delta
	while shop_arrivals >= 1.0:
		shop_arrivals -= 1.0
		_spawn_customer()
	for i in range(shop_queue.size() - 1, -1, -1):
		shop_queue[i]["wait"] = float(shop_queue[i]["wait"]) - delta
		if shop_queue[i]["wait"] <= 0.0:
			shop_queue.remove_at(i)
			missed_customers += 1
	shop_serve_progress += salesperson_rate() * delta
	while shop_serve_progress >= 1.0:
		if serviceable_customer() < 0:
			# Verkäufer wartet, sammelt aber keine Zeit auf Vorrat an
			shop_serve_progress = minf(shop_serve_progress, 1.0)
			break
		shop_serve_progress -= 1.0
		sell(true)
	_restock()


func _spawn_customer() -> void:
	var total := 0.0
	for b in Balance.BIKES:
		if bike_unlocked(b["id"]):
			total += float(b["weight"])
	var pick := rng.randf() * total
	var wanted: String = Balance.BIKES[0]["id"]
	for b in Balance.BIKES:
		if not bike_unlocked(b["id"]):
			continue
		pick -= float(b["weight"])
		if pick <= 0.0:
			wanted = b["id"]
			break
	if shop_queue.size() < Balance.SHOP_QUEUE_MAX:
		shop_queue.append({"bike": wanted, "wait": Balance.SHOP_PATIENCE})
	else:
		missed_customers += 1


## Bestellt automatisch nach: das Lager wird gleichmäßig auf das Sortiment verteilt.
func _restock() -> void:
	var assorted: Array[String] = []
	for b in Balance.BIKES:
		if in_assortment(b["id"]):
			assorted.append(b["id"])
	if assorted.is_empty():
		return
	var capacity := shop_capacity()
	var target := maxi(1, floori(capacity / float(assorted.size())))
	for id in assorted:
		var cost := BigNumber.of(Balance.bike(id)["buy"])
		while stock_of(id) < target and stock_total() < capacity and money.gte(cost):
			money = money.sub(cost)
			stock[id] = stock_of(id) + 1


## Offline verkauft der Verkäufer gedämpft weiter, solange das Sortiment nachbestellt wird.
func _offline_shop(seconds: float, report: Dictionary) -> void:
	if not shop_open() or salesperson_rate() <= 0.0:
		return
	var total_weight := 0.0
	var served_weight := 0.0
	var profit_sum := 0.0
	var rep_sum := 0.0
	var knowhow_sum := 0.0
	for b in Balance.BIKES:
		if not bike_unlocked(b["id"]):
			continue
		var w := float(b["weight"])
		total_weight += w
		if not in_assortment(b["id"]):
			continue
		served_weight += w
		var reward := bike_reward(b["id"])
		profit_sum += w * (reward["money"].to_float() - float(b["buy"]))
		rep_sum += w * reward["rep"].to_float()
		knowhow_sum += w * reward["knowhow"].to_float()
	if served_weight <= 0.0:
		return
	var demand := customer_rate() * served_weight / total_weight
	var rate := minf(demand, salesperson_rate()) * Balance.OFFLINE_RATE
	var sales := floorf(rate * seconds)
	if sales < 1.0:
		return
	var gained := {
		"money": BigNumber.of(profit_sum / served_weight).mul_f(sales),
		"rep": BigNumber.of(rep_sum / served_weight).mul_f(sales),
		"knowhow": BigNumber.of(knowhow_sum / served_weight).mul_f(sales),
	}
	_gain(gained)
	run_sales += int(sales)
	report["sales"] = int(sales)
	report["money"] = gained["money"]
	report["rep"] = gained["rep"]


# --- Radmarke (Phase 3) --------------------------------------------------------

func brand_open() -> bool:
	return phase >= 3


func generation(sparte_id: String) -> int:
	return int(brand.get(sparte_id, {}).get("gen", 0))


func price_class(sparte_id: String) -> int:
	return int(brand.get(sparte_id, {}).get("class", Balance.DEFAULT_PRICE_CLASS))


func set_price_class(sparte_id: String, index: int) -> void:
	if generation(sparte_id) <= 0:
		return
	brand[sparte_id]["class"] = clampi(index, 0, Balance.PRICE_CLASSES.size() - 1)


## Höchste entwickelbare Generation (Stahl = 1, mit Rahmenmaterial bis Titan = 4).
func max_generation() -> int:
	return mini(1 + knowhow_level("frame_material"), Balance.MATERIALS.size())


func sparte_unlocked(sparte_id: String) -> bool:
	var requirement := str(Balance.sparte(sparte_id).get("requires", ""))
	return requirement == "" or knowhow_level(requirement) > 0


func dev_cost(sparte_id: String) -> BigNumber:
	var s := Balance.sparte(sparte_id)
	return BigNumber.of(s["dev_cost"]).mul(BigNumber.of(Balance.GEN_COST_GROWTH).pow_f(generation(sparte_id)))


func dev_work(sparte_id: String) -> float:
	return float(Balance.sparte(sparte_id)["dev_work"]) * pow(Balance.GEN_WORK_GROWTH, generation(sparte_id))


func can_start_dev(sparte_id: String) -> bool:
	return brand_open() and dev_project.is_empty() and sparte_unlocked(sparte_id) \
		and generation(sparte_id) < max_generation() and money.gte(dev_cost(sparte_id))


func start_dev(sparte_id: String) -> bool:
	if not can_start_dev(sparte_id):
		return false
	money = money.sub(dev_cost(sparte_id))
	dev_project = {"sparte": sparte_id, "work": 0.0}
	return true


func design_rate() -> float:
	return _upgrade_value("design_office") * upgrade_level("design_office") * speed_mult()


## Ein Tipp auf „Konstruieren": dieselbe Handarbeit wie in der Werkstatt.
func design_tap() -> bool:
	if dev_project.is_empty():
		return false
	total_taps += 1
	_add_design_work(tap_power())
	return true


func _add_design_work(amount: float) -> void:
	if dev_project.is_empty():
		return
	dev_project["work"] = float(dev_project["work"]) + amount
	var sparte_id: String = dev_project["sparte"]
	if dev_project["work"] < dev_work(sparte_id):
		return
	var gen := generation(sparte_id) + 1
	brand[sparte_id] = {"gen": gen, "class": price_class(sparte_id)}
	dev_project = {}
	knowhow = knowhow.add(BigNumber.of(Balance.DEV_KNOWHOW * gen))
	model_developed.emit(sparte_id, gen)


func brand_quality(sparte_id: String) -> float:
	var bonus := 1.0 + _upgrade_value("test_lab") * upgrade_level("test_lab") \
		+ _knowhow_value("aero") * knowhow_level("aero") \
		+ _knowhow_value("quality_spread") * knowhow_level("quality_spread")
	return generation(sparte_id) * bonus


func brand_price(sparte_id: String) -> float:
	var s := Balance.sparte(sparte_id)
	var cls: Dictionary = Balance.PRICE_CLASSES[price_class(sparte_id)]
	var gen_factor := 1.0 + Balance.GEN_PRICE_BONUS * (generation(sparte_id) - 1)
	var tech := 1.0 + _knowhow_value("e_shifting") * knowhow_level("e_shifting")
	return float(s["price"]) * float(cls["price"]) * gen_factor * tech


func brand_unit_cost(sparte_id: String) -> float:
	var s := Balance.sparte(sparte_id)
	var cls: Dictionary = Balance.PRICE_CLASSES[price_class(sparte_id)]
	var gen_factor := 1.0 + Balance.GEN_PRICE_BONUS * (generation(sparte_id) - 1)
	var saving := 1.0 - _knowhow_value("unit_cost") * knowhow_level("unit_cost")
	return float(s["price"]) * float(cls["price"]) * gen_factor * float(cls["cost"]) * saving


## Anteil, den das Modell bei voller Reichweite gegen die Konkurrenz holen würde.
func brand_appeal_share(sparte_id: String, region_id := "home") -> float:
	if generation(sparte_id) <= 0:
		return 0.0
	var appeal := brand_quality(sparte_id) * float(Balance.PRICE_CLASSES[price_class(sparte_id)]["appeal"])
	appeal *= campaign_mult(region_id)
	return appeal / (appeal + float(Balance.sparte(sparte_id)["competitor"]))


func brand_reach() -> float:
	return minf(1.0, Balance.BRAND_BASE_REACH + _upgrade_value("dealers") * upgrade_level("dealers"))


func production_capacity() -> float:
	var base := Balance.BRAND_BASE_PRODUCTION + _upgrade_value("factory") * upgrade_level("factory")
	var automation := 1.0 + _knowhow_value("automation") * knowhow_level("automation")
	var plants := 1.0 + _knowhow_value("second_plant") * knowhow_level("second_plant")
	var mass := 1.0 + _upgrade_value("mass_production") * upgrade_level("mass_production")
	return base * automation * plants * mass


## Verkäufe je Sparte und Region (Räder/s): Nachfrage in allen erschlossenen
## Regionen, gedeckelt durch die Produktion, die anteilig zur Nachfrage verteilt wird.
func brand_rates() -> Dictionary:
	var demand := {}
	var total_demand := 0.0
	var reach := brand_reach() * (1.0 + _upgrade_value("distribution_center") * upgrade_level("distribution_center"))
	for r in markets_in_scope():
		if not region_open(r["id"]):
			continue
		for s in Balance.SPARTEN:
			var d := regional_market(r["id"], s["id"]) * brand_appeal_share(s["id"], r["id"]) * reach
			demand[[r["id"], s["id"]]] = d
			total_demand += d
	var fill := 1.0 if total_demand <= 0.0 else minf(1.0, production_capacity() / total_demand)
	var units := {}
	var regions := {}
	var total_units := 0.0
	var profit := 0.0
	for s in Balance.SPARTEN:
		units[s["id"]] = 0.0
	for key in demand:
		var sold: float = demand[key] * fill
		units[key[1]] += sold
		regions[key[0]] = float(regions.get(key[0], 0.0)) + sold
		total_units += sold
	for s in Balance.SPARTEN:
		if units[s["id"]] > 0.0:
			profit += units[s["id"]] * (brand_price(s["id"]) - brand_unit_cost(s["id"]))
	return {
		"units": units, "regions": regions, "total_units": total_units, "demand": total_demand,
		"profit": profit * legend_mult(), "rep": total_units * Balance.BRAND_REP_PER_BIKE * reputation_mult(),
	}


## Phase 3 kennt nur die Heimatregion; ab Phase 4 zählt das ganze Land.
func markets_in_scope() -> Array:
	if phase >= 4:
		return Balance.REGIONS
	return [Balance.REGIONS[0]]


func regional_market(region_id: String, sparte_id: String) -> float:
	var r := Balance.region(region_id)
	return float(Balance.sparte(sparte_id)["market"]) * float(r["size"]) * float(r["prefs"].get(sparte_id, 1.0))


func region_market_size(region_id: String) -> float:
	var total := 0.0
	for s in Balance.SPARTEN:
		total += regional_market(region_id, s["id"])
	return total


func market_size() -> float:
	var total := 0.0
	for r in markets_in_scope():
		total += region_market_size(r["id"])
	return total


func market_share() -> float:
	if not brand_open():
		return 0.0
	return brand_rates()["total_units"] / market_size()


# --- National (Phase 4) ---------------------------------------------------------

func national_open() -> bool:
	return phase >= 4


func region_open(region_id: String) -> bool:
	return region_id == "home" or regions_open.has(region_id)


func region_cost(region_id: String) -> BigNumber:
	return BigNumber.of(Balance.region(region_id)["open_cost"])


func can_open_region(region_id: String) -> bool:
	return national_open() and not region_open(region_id) and money.gte(region_cost(region_id))


func open_region(region_id: String) -> bool:
	if not can_open_region(region_id):
		return false
	money = money.sub(region_cost(region_id))
	regions_open[region_id] = true
	return true


func campaign_cost(region_id: String) -> BigNumber:
	return BigNumber.of(Balance.CAMPAIGN_BASE_COST * float(Balance.region(region_id)["size"]))


func campaign_duration() -> float:
	return Balance.CAMPAIGN_DURATION * (1.0 + _upgrade_value("marketing_dept") * upgrade_level("marketing_dept"))


func campaign_time_left(region_id: String) -> float:
	for c in campaigns:
		if c["region"] == region_id:
			return float(c["time_left"])
	return 0.0


func campaign_mult(region_id: String) -> float:
	if campaign_time_left(region_id) <= 0.0:
		return 1.0
	return 1.0 + Balance.CAMPAIGN_EFFECT * (1.0 + _upgrade_value("marketing_dept") * upgrade_level("marketing_dept"))


func can_start_campaign(region_id: String) -> bool:
	return national_open() and region_open(region_id) and campaign_time_left(region_id) <= 0.0 \
		and campaigns.size() < Balance.CAMPAIGN_SLOTS and money.gte(campaign_cost(region_id))


func start_campaign(region_id: String) -> bool:
	if not can_start_campaign(region_id):
		return false
	money = money.sub(campaign_cost(region_id))
	campaigns.append({"region": region_id, "time_left": campaign_duration()})
	return true


func _tick_campaigns(delta: float) -> void:
	for i in range(campaigns.size() - 1, -1, -1):
		campaigns[i]["time_left"] = float(campaigns[i]["time_left"]) - delta
		if campaigns[i]["time_left"] <= 0.0:
			campaigns.remove_at(i)


func _tick_brand(delta: float) -> void:
	_add_design_work(design_rate() * delta)
	_tick_campaigns(delta)
	var rates := brand_rates()
	if rates["total_units"] <= 0.0:
		return
	run_bikes_built += rates["total_units"] * delta
	_gain({
		"money": BigNumber.of(rates["profit"] * delta),
		"rep": BigNumber.of(rates["rep"] * delta),
		"knowhow": BigNumber.zero(),
	})


func _offline_brand(seconds: float, report: Dictionary) -> void:
	if not brand_open():
		return
	# Kampagnen laufen offline weiter ab
	_tick_campaigns(seconds)
	var rates := brand_rates()
	if rates["total_units"] <= 0.0:
		return
	var factor := seconds * Balance.OFFLINE_RATE
	var gained := {
		"money": BigNumber.of(rates["profit"]).mul_f(factor),
		"rep": BigNumber.of(rates["rep"]).mul_f(factor),
		"knowhow": BigNumber.zero(),
	}
	_gain(gained)
	run_bikes_built += rates["total_units"] * factor
	report["bikes"] = int(rates["total_units"] * factor)
	report["money"] = report["money"].add(gained["money"])
	report["rep"] = report["rep"].add(gained["rep"])


# --- Ausbau --------------------------------------------------------------------

func upgrade_cost(id: String) -> BigNumber:
	return _cost(Balance.UPGRADES[id], upgrade_level(id))


func upgrade_unlocked(id: String) -> bool:
	var def: Dictionary = Balance.UPGRADES[id]
	return phase >= int(def["phase"]) and reputation.gte(BigNumber.of(def.get("requires_rep", 0.0)))


func upgrade_maxed(id: String) -> bool:
	return _maxed(Balance.UPGRADES[id], upgrade_level(id))


func can_buy_upgrade(id: String) -> bool:
	return upgrade_unlocked(id) and not upgrade_maxed(id) and money.gte(upgrade_cost(id))


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	money = money.sub(upgrade_cost(id))
	upgrades[id] = upgrade_level(id) + 1
	upgrades_changed.emit()
	return true


# --- Know-how-Baum ------------------------------------------------------------

func knowhow_cost(id: String) -> BigNumber:
	return _cost(Balance.KNOWHOW_NODES[id], knowhow_level(id))


func branch_unlocked(branch_id: String) -> bool:
	var branch := Balance.branch_def(branch_id)
	return not branch.is_empty() and phase >= int(branch["phase"])


func knowhow_maxed(id: String) -> bool:
	return _maxed(Balance.KNOWHOW_NODES[id], knowhow_level(id))


func can_buy_knowhow(id: String) -> bool:
	var def: Dictionary = Balance.KNOWHOW_NODES[id]
	return branch_unlocked(def["branch"]) and not knowhow_maxed(id) and knowhow.gte(knowhow_cost(id))


func buy_knowhow(id: String) -> bool:
	if not can_buy_knowhow(id):
		return false
	knowhow = knowhow.sub(knowhow_cost(id))
	knowhow_levels[id] = knowhow_level(id) + 1
	upgrades_changed.emit()
	return true


static func _cost(def: Dictionary, level: int) -> BigNumber:
	return BigNumber.of(def["base_cost"]).mul(BigNumber.of(def["growth"]).pow_f(level))


static func _maxed(def: Dictionary, level: int) -> bool:
	var max_level := int(def.get("max_level", 0))
	return max_level > 0 and level >= max_level


# --- Phasen -------------------------------------------------------------------

func phase_def() -> Dictionary:
	return Balance.phase_def(phase)


func phase_goal_met() -> bool:
	var def := phase_def()
	return reputation.gte(BigNumber.of(def["goal_rep"])) \
		and money.gte(BigNumber.of(def["goal_money"])) \
		and knowhow.gte(BigNumber.of(def.get("goal_knowhow", 0.0))) \
		and market_share() >= float(def.get("goal_share", 0.0))


func can_advance_phase() -> bool:
	return phase_goal_met() and Balance.is_phase_playable(phase + 1)


func advance_phase() -> bool:
	if not can_advance_phase():
		return false
	var def := phase_def()
	money = money.sub(BigNumber.of(def["goal_money"]))
	knowhow = knowhow.sub(BigNumber.of(def.get("goal_knowhow", 0.0)))
	phase += 1
	if shop_open():
		_restock()
	phase_changed.emit()
	upgrades_changed.emit()
	return true


# --- Prestige -----------------------------------------------------------------

func pending_legend() -> BigNumber:
	return run_money.square_root().mul_f(Balance.LEGEND_K).floored()


func can_prestige() -> bool:
	return pending_legend().gte(BigNumber.of(1.0))


## Zahlt Legende aus und startet den Run neu. Liefert die gewonnene Legende.
func prestige() -> BigNumber:
	var gained := pending_legend()
	if gained.lt(BigNumber.of(1.0)):
		return BigNumber.zero()
	legend = legend.add(gained)
	prestige_count += 1
	reset_run()
	return gained


# --- Offline-Fortschritt -------------------------------------------------------

## Der Lehrling arbeitet offline mit gedämpfter Rate weiter. Gerechnet wird mit dem
## Durchschnitt der schnellen Aufträge, damit auch Tage ohne Schleife gehen.
func apply_offline(seconds: float) -> Dictionary:
	var report := {"seconds": seconds, "orders": 0, "sales": 0, "money": BigNumber.zero(), "rep": BigNumber.zero()}
	if seconds <= 0.0:
		return report
	_offline_shop(seconds, report)
	_offline_brand(seconds, report)
	var rate := apprentice_rate() * Balance.OFFLINE_RATE
	if rate <= 0.0:
		return report
	var templates := Balance.templates_of_kind("quick")
	var tier := customer_tier()
	var work_sum := 0.0
	var money_sum := BigNumber.zero()
	var rep_sum := BigNumber.zero()
	for tpl in templates:
		var order := {"tpl": tpl["id"], "tier": tier, "var": 1.0}
		work_sum += order_work(order)
		var reward := order_reward(order)
		money_sum = money_sum.add(reward["money"])
		rep_sum = rep_sum.add(reward["rep"])
	var n := float(templates.size())
	var count := floorf(rate * seconds / (work_sum / n))
	if count < 1.0:
		apprentice_progress += rate * seconds
		return report
	var gained := {
		"money": money_sum.mul_f(count / n),
		"rep": rep_sum.mul_f(count / n),
		"knowhow": BigNumber.zero(),
	}
	_gain(gained)
	run_orders += int(count)
	total_orders += int(count)
	report["orders"] = int(count)
	report["money"] = report["money"].add(gained["money"])
	report["rep"] = report["rep"].add(gained["rep"])
	return report


# --- Speichern ----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"money": money.to_save(),
		"reputation": reputation.to_save(),
		"knowhow": knowhow.to_save(),
		"run_money": run_money.to_save(),
		"phase": phase,
		"upgrades": upgrades.duplicate(),
		"knowhow_levels": knowhow_levels.duplicate(),
		"board": board.duplicate(true),
		"active_order": active_order.duplicate(),
		"active_progress": active_progress,
		"apprentice_order": apprentice_order.duplicate(),
		"apprentice_progress": apprentice_progress,
		"run_time": run_time,
		"run_orders": run_orders,
		"stock": stock.duplicate(),
		"shop_disabled": shop_disabled.duplicate(),
		"shop_queue": shop_queue.duplicate(true),
		"shop_arrivals": shop_arrivals,
		"shop_serve_progress": shop_serve_progress,
		"run_sales": run_sales,
		"missed_customers": missed_customers,
		"brand": brand.duplicate(true),
		"dev_project": dev_project.duplicate(),
		"run_bikes_built": run_bikes_built,
		"regions_open": regions_open.duplicate(),
		"campaigns": campaigns.duplicate(true),
		"legend": legend.to_save(),
		"prestige_count": prestige_count,
		"lifetime_money": lifetime_money.to_save(),
		"total_orders": total_orders,
		"total_taps": total_taps,
		"total_time": total_time,
	}


## Lädt einen Spielstand; fehlende oder kaputte Felder fallen auf Startwerte zurück.
func from_dict(d: Dictionary) -> void:
	money = BigNumber.from_save(d.get("money"))
	reputation = BigNumber.from_save(d.get("reputation"))
	knowhow = BigNumber.from_save(d.get("knowhow"))
	run_money = BigNumber.from_save(d.get("run_money"))
	phase = clampi(int(d.get("phase", 1)), 1, Balance.PHASES.size())
	upgrades = _clean_levels(d.get("upgrades"), Balance.UPGRADES)
	knowhow_levels = _clean_levels(d.get("knowhow_levels"), Balance.KNOWHOW_NODES)
	board.clear()
	var saved_board: Variant = d.get("board")
	if saved_board is Array:
		for order in saved_board:
			if board.size() < Balance.BOARD_SIZE and _valid_order(order):
				board.append(_clean_order(order))
	_fill_board()
	active_order = _clean_order(d.get("active_order")) if _valid_order(d.get("active_order")) else {}
	active_progress = maxf(0.0, float(d.get("active_progress", 0.0)))
	apprentice_order = _clean_order(d.get("apprentice_order")) if _valid_order(d.get("apprentice_order")) else {}
	apprentice_progress = maxf(0.0, float(d.get("apprentice_progress", 0.0)))
	run_time = float(d.get("run_time", 0.0))
	run_orders = int(d.get("run_orders", 0))
	stock = {}
	var saved_stock: Variant = d.get("stock")
	if saved_stock is Dictionary:
		for id in saved_stock:
			if not Balance.bike(str(id)).is_empty():
				stock[str(id)] = maxi(0, int(saved_stock[id]))
	shop_disabled = {}
	var saved_disabled: Variant = d.get("shop_disabled")
	if saved_disabled is Dictionary:
		for id in saved_disabled:
			if not Balance.bike(str(id)).is_empty():
				shop_disabled[str(id)] = true
	shop_queue.clear()
	var saved_queue: Variant = d.get("shop_queue")
	if saved_queue is Array:
		for c in saved_queue:
			if c is Dictionary and not Balance.bike(str(c.get("bike", ""))).is_empty() and shop_queue.size() < Balance.SHOP_QUEUE_MAX:
				shop_queue.append({"bike": str(c["bike"]), "wait": float(c.get("wait", Balance.SHOP_PATIENCE))})
	shop_arrivals = float(d.get("shop_arrivals", 0.0))
	shop_serve_progress = float(d.get("shop_serve_progress", 0.0))
	run_sales = int(d.get("run_sales", 0))
	missed_customers = int(d.get("missed_customers", 0))
	brand = {}
	var saved_brand: Variant = d.get("brand")
	if saved_brand is Dictionary:
		for id in saved_brand:
			var entry: Variant = saved_brand[id]
			if not Balance.sparte(str(id)).is_empty() and entry is Dictionary:
				brand[str(id)] = {
					"gen": clampi(int(entry.get("gen", 0)), 0, Balance.MATERIALS.size()),
					"class": clampi(int(entry.get("class", Balance.DEFAULT_PRICE_CLASS)), 0, Balance.PRICE_CLASSES.size() - 1),
				}
	dev_project = {}
	var saved_dev: Variant = d.get("dev_project")
	if saved_dev is Dictionary and not Balance.sparte(str(saved_dev.get("sparte", ""))).is_empty():
		dev_project = {"sparte": str(saved_dev["sparte"]), "work": maxf(0.0, float(saved_dev.get("work", 0.0)))}
	run_bikes_built = float(d.get("run_bikes_built", 0.0))
	regions_open = {}
	var saved_regions: Variant = d.get("regions_open")
	if saved_regions is Dictionary:
		for id in saved_regions:
			if not Balance.region(str(id)).is_empty():
				regions_open[str(id)] = true
	campaigns.clear()
	var saved_campaigns: Variant = d.get("campaigns")
	if saved_campaigns is Array:
		for c in saved_campaigns:
			if c is Dictionary and not Balance.region(str(c.get("region", ""))).is_empty() and campaigns.size() < Balance.CAMPAIGN_SLOTS:
				campaigns.append({"region": str(c["region"]), "time_left": maxf(0.0, float(c.get("time_left", 0.0)))})
	legend = BigNumber.from_save(d.get("legend"))
	prestige_count = int(d.get("prestige_count", 0))
	lifetime_money = BigNumber.from_save(d.get("lifetime_money"))
	total_orders = int(d.get("total_orders", 0))
	total_taps = int(d.get("total_taps", 0))
	total_time = float(d.get("total_time", 0.0))
	_last_tier = customer_tier()
	_emit_all()


static func _clean_levels(source: Variant, defs: Dictionary) -> Dictionary:
	var out := {}
	if source is Dictionary:
		for id in source:
			if defs.has(id):
				out[id] = maxi(0, int(source[id]))
	return out


static func _valid_order(order: Variant) -> bool:
	return order is Dictionary \
		and not Balance.order_template(str(order.get("tpl", ""))).is_empty() \
		and order.has("tier") and order.has("var")


static func _clean_order(order: Dictionary) -> Dictionary:
	return {"tpl": str(order["tpl"]), "tier": maxi(0, int(order["tier"])), "var": float(order["var"])}


func _emit_all() -> void:
	board_changed.emit()
	upgrades_changed.emit()
	phase_changed.emit()
