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


func step(dt: float) -> void:
	_time += dt
	model.tick(dt)
	_tap_budget += taps_per_second * dt
	while _tap_budget >= 1.0:
		_tap_budget -= 1.0
		if model.active_order.is_empty():
			model.accept_order(_best_order())
		model.tap()
	_shop()


func _best_order() -> int:
	var def := model.phase_def()
	var rep_progress := model.reputation.to_float() / float(def["goal_rep"])
	var money_progress := model.money.to_float() / float(def["goal_money"])
	var want_rep := rep_progress < money_progress
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
		score += reward["knowhow"].to_float() * 0.05
		if score > best_score:
			best_score = score
			best = i
	return best


func _shop() -> void:
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
		for id in Balance.KNOWHOW_NODES:
			if model.buy_knowhow(id):
				bought = true


func _on_tier_changed(tier: int) -> void:
	_mark("Kundschaft %d" % tier)


func _mark(name: String) -> void:
	if not milestones.has(name):
		milestones[name] = _time
