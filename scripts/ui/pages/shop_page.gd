class_name ShopPage
extends Page
## Radladen (Phase 2): wartende Kundschaft bedienen, Sortiment und Lager.

var _rates: Label
var _queue_rows: Array[Dictionary] = []
var _sell_button: Button
var _bump_tween: Tween
var _storage_label: Label
var _missed_label: Label
var _bike_rows := {}


func _build() -> void:
	content.add_child(UI.label("Radladen", "TitleLabel"))
	_rates = UI.label("", "MutedLabel", true)
	content.add_child(_rates)

	var floor_card := UI.card()
	var fv := UI.vbox(12)
	floor_card.add_child(fv)
	fv.add_child(UI.label("Kundschaft im Laden", "SubtitleLabel"))
	for i in Balance.SHOP_QUEUE_MAX:
		var row := UI.hbox(10)
		var wish := UI.label("", "SmallLabel")
		wish.custom_minimum_size.x = 250
		row.add_child(wish)
		var status := UI.label("", "MutedLabel")
		status.custom_minimum_size.x = 150
		row.add_child(status)
		var bar := UI.progress(UiTheme.REPUTATION, 10)
		row.add_child(bar)
		fv.add_child(row)
		_queue_rows.append({"row": row, "name": wish, "status": status, "bar": bar, "available": null})
	_sell_button = UI.button("Verkaufen!", _on_sell_pressed, "BigButton")
	_sell_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_sell_button.custom_minimum_size.y = 130
	_sell_button.resized.connect(func() -> void: _sell_button.pivot_offset = _sell_button.size / 2.0)
	fv.add_child(_sell_button)
	content.add_child(floor_card)

	var stock_card := UI.card()
	var sv := UI.vbox(10)
	stock_card.add_child(sv)
	var head := UI.hbox()
	head.add_child(UI.label("Sortiment", "SubtitleLabel"))
	head.add_child(UI.spacer())
	_storage_label = UI.label("", "MutedLabel")
	_storage_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_storage_label)
	sv.add_child(head)
	sv.add_child(UI.label("Im Sortiment wird automatisch nachbestellt; das Lager wird gleichmäßig aufgeteilt.", "MutedLabel", true))
	for b in Balance.BIKES:
		var row := UI.hbox(12)
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(b["name"], "SubtitleLabel"))
		var detail := UI.label("", "MutedLabel")
		info.add_child(detail)
		row.add_child(info)
		var toggle := UI.button("", _on_toggle.bind(b["id"]), "SecondaryButton")
		toggle.custom_minimum_size = Vector2(210, 76)
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(toggle)
		sv.add_child(row)
		_bike_rows[b["id"]] = {"detail": detail, "toggle": toggle}
	_missed_label = UI.label("", "MutedLabel")
	sv.add_child(_missed_label)
	content.add_child(stock_card)
	model.sale_completed.connect(_on_sale_completed)


func refresh() -> void:
	_rates.text = "%s Kunden/min · Verkäufer %s Verkäufe/min" % [
		NumberFormat.num(model.customer_rate() * 60.0, 1), NumberFormat.num(model.salesperson_rate() * 60.0, 1)]
	var serviceable := model.serviceable_customer()
	for i in _queue_rows.size():
		var r: Dictionary = _queue_rows[i]
		var has_customer := i < model.shop_queue.size()
		r["row"].visible = has_customer
		if not has_customer:
			continue
		var customer: Dictionary = model.shop_queue[i]
		var bike_id: String = customer["bike"]
		r["name"].text = "Will: " + str(Balance.bike(bike_id)["name"])
		var available := model.stock_of(bike_id) > 0
		if r["available"] != available:
			r["available"] = available
			r["status"].text = "auf Lager" if available else "nicht da"
			UI.tint(r["status"], UiTheme.MONEY if available else UiTheme.DANGER)
		r["bar"].value = clampf(float(customer["wait"]) / Balance.SHOP_PATIENCE, 0.0, 1.0)
	_sell_button.disabled = serviceable < 0
	_sell_button.text = "Verkaufen!" if not model.shop_queue.is_empty() else "Warte auf Kundschaft …"
	_storage_label.text = "Lager %d/%d" % [model.stock_total(), model.shop_capacity()]
	for b in Balance.BIKES:
		var row: Dictionary = _bike_rows[b["id"]]
		var toggle: Button = row["toggle"]
		if not model.bike_unlocked(b["id"]):
			row["detail"].text = "Ab %s Ruf" % NumberFormat.num(float(b["requires_rep"]), 0)
			toggle.text = "Gesperrt"
			toggle.disabled = true
			continue
		var reward := model.bike_reward(b["id"])
		row["detail"].text = "%d auf Lager · Einkauf %s · Verkauf %s" % [
			model.stock_of(b["id"]), NumberFormat.money(BigNumber.of(b["buy"])), NumberFormat.money(reward["money"])]
		toggle.disabled = false
		toggle.text = "Im Sortiment" if model.in_assortment(b["id"]) else "Ausgelistet"
	_missed_label.text = "Verkauft: %s · Kundschaft verpasst: %s" % [
		NumberFormat.num(model.run_sales, 0), NumberFormat.num(model.missed_customers, 0)]


func _on_toggle(id: String) -> void:
	model.set_assortment(id, not model.in_assortment(id))


func _on_sell_pressed() -> void:
	model.sell(false)
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	_sell_button.scale = Vector2(0.96, 0.96)
	_bump_tween = _sell_button.create_tween()
	_bump_tween.tween_property(_sell_button, "scale", Vector2.ONE, 0.12)


func _on_sale_completed(_bike_id: String, reward: Dictionary, by_staff: bool) -> void:
	if not is_visible_in_tree():
		return
	var center := _sell_button.global_position + _sell_button.size / 2.0
	if by_staff:
		center.y -= 60.0
	UI.float_text(fx, center, "+" + NumberFormat.money(reward["money"]), UiTheme.MONEY, 26 if by_staff else 38)
	if not by_staff:
		UI.float_text(fx, center + Vector2(0, 46), "+%s Ruf" % NumberFormat.num(reward["rep"].to_float(), 1), UiTheme.REPUTATION, 30)
