class_name KnowhowPage
extends Page
## Know-how-Baum: vier Äste, die mit den Phasen freigeschaltet werden.

var _balance_label: Label
var _rows := {}
var _locked_cards := {}


func _build() -> void:
	content.add_child(UI.label("Know-how-Baum", "TitleLabel"))
	var intro := UI.hbox(10)
	intro.add_child(UI.icon("knowhow", 34))
	_balance_label = UI.label("", "SmallLabel", true)
	intro.add_child(_balance_label)
	content.add_child(intro)
	content.add_child(UI.label("Know-how gibt es für knifflige Fälle. Der Baum wird bei jedem Prestige zurückgesetzt.", "MutedLabel", true))
	for branch in Balance.KNOWHOW_BRANCHES:
		var header := UI.hbox(10)
		header.add_child(UI.label("Ast: " + str(branch["name"]), "SubtitleLabel"))
		content.add_child(header)
		var locked := UI.card()
		var locked_box := UI.vbox(6)
		locked.add_child(locked_box)
		locked_box.add_child(UI.label("Ab Phase %d · %s" % [branch["phase"], Balance.phase_def(branch["phase"])["name"]], "SmallLabel"))
		locked_box.add_child(UI.label(branch["desc"], "MutedLabel", true))
		content.add_child(locked)
		_locked_cards[branch["id"]] = locked
		for id in Balance.KNOWHOW_NODES:
			var def: Dictionary = Balance.KNOWHOW_NODES[id]
			if def["branch"] != branch["id"]:
				continue
			var row := PurchaseRow.new(def["name"], def["desc"], _buy.bind(id), "knowhow")
			content.add_child(row)
			_rows[id] = row


func refresh() -> void:
	_balance_label.text = "%s Know-how verfügbar" % NumberFormat.big(model.knowhow)
	for branch_id in _locked_cards:
		_locked_cards[branch_id].visible = not model.branch_unlocked(branch_id)
	for id in _rows:
		var row: PurchaseRow = _rows[id]
		var def: Dictionary = Balance.KNOWHOW_NODES[id]
		row.visible = model.branch_unlocked(def["branch"])
		if not row.visible:
			continue
		var level := model.knowhow_level(id)
		var effect := PurchaseRow.effect_text(def, level)
		var level_text := PurchaseRow.level_text(def, level)
		if model.knowhow_maxed(id):
			row.set_state(level_text, effect, "Maximal", false, false)
		else:
			row.set_state(level_text, effect, NumberFormat.big(model.knowhow_cost(id)), model.can_buy_knowhow(id))


func _buy(id: String) -> void:
	model.buy_knowhow(id)
