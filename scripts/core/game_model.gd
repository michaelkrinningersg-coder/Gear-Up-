class_name GameModel
extends RefCounted
## Komplette Spiellogik ohne Szenenbaum, damit sie headless testbar ist.
## Die Oberfläche liest den Zustand direkt und hört auf die Signale.

signal board_changed
signal upgrades_changed
signal order_completed(order: Dictionary, reward: Dictionary, by_apprentice: bool)
signal customer_tier_changed(tier: int)
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
	return _upgrade_value("apprentice") * upgrade_level("apprentice") * speed_mult()


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
	return reputation.gte(BigNumber.of(def["goal_rep"])) and money.gte(BigNumber.of(def["goal_money"]))


func can_advance_phase() -> bool:
	return phase_goal_met() and Balance.is_phase_playable(phase + 1)


func advance_phase() -> bool:
	if not can_advance_phase():
		return false
	money = money.sub(BigNumber.of(phase_def()["goal_money"]))
	phase += 1
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
	var report := {"seconds": seconds, "orders": 0, "money": BigNumber.zero(), "rep": BigNumber.zero()}
	var rate := apprentice_rate() * Balance.OFFLINE_RATE
	if seconds <= 0.0 or rate <= 0.0:
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
	report["money"] = gained["money"]
	report["rep"] = gained["rep"]
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
