class_name SimBot
extends RefCounted
## Einfacher Spieler-Bot für Balancing-Simulationen: tippt mit fester Rate,
## wählt Aufträge nach dem knapperen Ziel und kauft das Günstigste, was sich lohnt.

var model: GameModel
var taps_per_second: float
## Anteil des Kontostands, den der Bot höchstens für ein Upgrade ausgibt.
var spend_fraction := 0.7
## Zeitpunkte (Sekunden) wichtiger Ereignisse, z. B. „Lehrling", „Kundschaft 2".
var milestones := {}

var _time := 0.0
var _tap_budget := 0.0


func _init(game_model: GameModel, tps := 4.0) -> void:
	model = game_model
	taps_per_second = tps
	model.customer_tier_changed.connect(_on_tier_changed)


## Simuliert bis zum Phasenziel; liefert die Zeit in Sekunden oder -1.
func run_until_goal(max_seconds: float, dt := 0.1) -> float:
	while _time < max_seconds:
		step(dt)
		if model.phase_goal_met():
			_mark("Phasenziel")
			return _time
	return -1.0


## Spielt bis zum Ziel der angegebenen Phase und steigt unterwegs auf; liefert Sekunden oder -1.
func run_until_phase_goal(target_phase: int, max_seconds: float, dt := 0.1) -> float:
	while _time < max_seconds:
		step(dt)
		_mark_subgoals()
		if not model.phase_goal_met():
			continue
		if model.phase >= target_phase:
			_mark("Ziel Phase %d" % model.phase)
			return _time
		if model.advance_phase():
			_mark("Phase %d" % model.phase)
	return -1.0


func step(dt: float) -> void:
	_time += dt
	model.tick(dt)
	_tap_budget += taps_per_second * dt
	while _tap_budget >= 1.0:
		_tap_budget -= 1.0
		if model.design_tap():
			continue
		if model.shop_open() and model.serviceable_customer() >= 0:
			model.sell()
			continue
		if model.active_order.is_empty():
			model.accept_order(_best_order())
		model.tap()
	_shop()


func _best_order() -> int:
	var def := model.phase_def()
	var rep_progress := model.reputation.to_float() / float(def["goal_rep"])
	var money_progress := model.money.to_float() / float(def["goal_money"])
	var knowhow_goal := float(def.get("goal_knowhow", 0.0))
	var knowhow_progress := model.knowhow.to_float() / knowhow_goal if knowhow_goal > 0.0 else INF
	var want_rep := rep_progress < money_progress
	var want_knowhow := knowhow_progress < minf(rep_progress, money_progress)
	var best := 0
	var best_score := -1.0
	for i in model.board.size():
		var order: Dictionary = model.board[i]
		var reward := model.order_reward(order)
		var work := model.order_work(order)
		var score: float
		if want_rep:
			score = reward["rep"].to_float() / work
		else:
			score = reward["money"].to_float() / work
		if want_knowhow:
			score = reward["knowhow"].to_float() / work
		score += reward["knowhow"].to_float() * 0.05
		if score > best_score:
			best_score = score
			best = i
	return best


func _shop() -> void:
	_manage_brand()
	var bought := true
	while bought:
		bought = false
		var cheapest := ""
		var cheapest_cost: BigNumber = null
		for id in Balance.UPGRADES:
			if not model.can_buy_upgrade(id):
				continue
			var cost := model.upgrade_cost(id)
			if cheapest_cost == null or cost.lt(cheapest_cost):
				cheapest = id
				cheapest_cost = cost
		if cheapest != "" and cheapest_cost.lte(model.money.mul_f(spend_fraction)):
			model.buy_upgrade(cheapest)
			if model.upgrade_level(cheapest) == 1:
				_mark(Balance.UPGRADES[cheapest]["name"])
			bought = true
		# Know-how nur ausgeben, solange das Phasenziel keins verlangt
		if float(model.phase_def().get("goal_knowhow", 0.0)) <= 0.0:
			for id in Balance.KNOWHOW_NODES:
				if model.buy_knowhow(id):
					bought = true


func _manage_brand() -> void:
	if not model.brand_open():
		return
	var def := model.phase_def()
	var share_goal := float(def.get("goal_share", 0.0))
	var want_share := share_goal > 0.0 and model.market_share() / share_goal < model.money.to_float() / float(def["goal_money"])
	for s in Balance.SPARTEN:
		model.set_price_class(s["id"], 0 if want_share else Balance.DEFAULT_PRICE_CLASS)
	if not model.dev_project.is_empty():
		return
	var best := ""
	for s in Balance.SPARTEN:
		if model.can_start_dev(s["id"]) and model.dev_cost(s["id"]).lte(model.money.mul_f(spend_fraction)):
			if best == "" or model.dev_cost(s["id"]).lt(model.dev_cost(best)):
				best = s["id"]
	if best != "":
		model.start_dev(best)
		_mark("Modell %s %d" % [best, model.generation(best) + 1])


func _mark_subgoals() -> void:
	var def := model.phase_def()
	var p := model.phase
	if model.reputation.gte(BigNumber.of(def["goal_rep"])):
		_mark("P%d Ruf" % p)
	if model.money.gte(BigNumber.of(def["goal_money"])):
		_mark("P%d Geld" % p)
	if model.knowhow.gte(BigNumber.of(def.get("goal_knowhow", 0.0))):
		_mark("P%d Know-how" % p)
	if model.market_share() >= float(def.get("goal_share", 0.0)):
		_mark("P%d Anteil" % p)


func _on_tier_changed(tier: int) -> void:
	_mark("Kundschaft %d" % tier)


func _mark(name: String) -> void:
	if not milestones.has(name):
		milestones[name] = _time
