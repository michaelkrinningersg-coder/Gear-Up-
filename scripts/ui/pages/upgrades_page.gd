class_name UpgradesPage
extends Page
## Ausbau: Ausbaustufen der Gebäude, bezahlt mit Geld.

var _rows := {}


func _build() -> void:
	content.add_child(UI.label("Ausbau", "TitleLabel"))
	content.add_child(UI.label("Jede Stufe macht deine Werkstatt schneller oder lukrativer. Die Kosten steigen mit jeder Stufe.", "MutedLabel", true))
	for id in Balance.UPGRADES:
		var def: Dictionary = Balance.UPGRADES[id]
		var row := PurchaseRow.new(def["name"], def["desc"], _buy.bind(id), "money")
		content.add_child(row)
		_rows[id] = row


func refresh() -> void:
	for id in _rows:
		var row: PurchaseRow = _rows[id]
		var def: Dictionary = Balance.UPGRADES[id]
		row.visible = model.phase >= int(def["phase"])
		if not row.visible:
			continue
		var level := model.upgrade_level(id)
		var effect := PurchaseRow.effect_text(def, level)
		var level_text := PurchaseRow.level_text(def, level)
		if model.upgrade_maxed(id):
			row.set_state(level_text, effect, "Maximal", false, false)
		elif not model.upgrade_unlocked(id):
			row.set_state(level_text, effect, "Ab %s Ruf" % NumberFormat.num(float(def.get("requires_rep", 0.0)), 0), false, false)
		else:
			row.set_state(level_text, effect, NumberFormat.money(model.upgrade_cost(id)), model.can_buy_upgrade(id))


func _buy(id: String) -> void:
	model.buy_upgrade(id)
