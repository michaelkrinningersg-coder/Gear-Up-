class_name WorkshopPage
extends Page
## Werkstatt: Phasenziel, aktueller Auftrag, Lehrling und Auftragsliste.

var _goal_title: Label
var _goal_rep_label: Label
var _goal_rep_bar: ProgressBar
var _goal_money_label: Label
var _goal_money_bar: ProgressBar
var _goal_button: Button

var _active_card: PanelContainer
var _order_name: Label
var _order_badge: PanelContainer
var _order_bar: ProgressBar
var _order_work: Label
var _order_reward: Label
var _work_button: Button
var _bump_tween: Tween

var _apprentice_card: PanelContainer
var _apprentice_order: Label
var _apprentice_bar: ProgressBar
var _apprentice_rate: Label

var _board_section: VBoxContainer
var _tier_label: Label
var _board_box: VBoxContainer
var _board_rows: Array[Dictionary] = []
## Kurze Sperre nach einem fertigen Auftrag, damit schnelles Weitertippen
## nicht versehentlich ein Angebot annimmt.
var _board_locked_until := 0


func _build() -> void:
	content.add_child(_build_goal())
	# Aktiver Auftrag und Auftragsliste teilen sich den Platz: angenommen wird nur ohne aktiven Auftrag.
	_active_card = _build_active()
	content.add_child(_active_card)
	_board_section = UI.vbox(14)
	var head := UI.hbox()
	head.add_child(UI.label("Auftragsliste", "TitleLabel"))
	head.add_child(UI.spacer())
	_tier_label = UI.label("", "MutedLabel")
	_tier_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tier_label)
	_board_section.add_child(head)
	_board_box = UI.vbox(14)
	_board_section.add_child(_board_box)
	content.add_child(_board_section)
	_apprentice_card = _build_apprentice()
	content.add_child(_apprentice_card)
	model.board_changed.connect(_rebuild_board)
	model.order_completed.connect(_on_order_completed)
	_rebuild_board()


func _build_goal() -> PanelContainer:
	var card := UI.card()
	var v := UI.vbox(10)
	card.add_child(v)
	_goal_title = UI.label("", "SubtitleLabel")
	v.add_child(_goal_title)
	var rep := _goal_row(v, "reputation", UiTheme.REPUTATION)
	_goal_rep_label = rep[0]
	_goal_rep_bar = rep[1]
	var cash := _goal_row(v, "money", UiTheme.MONEY)
	_goal_money_label = cash[0]
	_goal_money_bar = cash[1]
	_goal_button = UI.button("", _on_goal_pressed)
	_goal_button.custom_minimum_size.y = 76
	v.add_child(_goal_button)
	return card


func _goal_row(parent: Control, icon_name: String, color: Color) -> Array:
	var row := UI.hbox(10)
	row.add_child(UI.icon(icon_name, 30))
	var l := UI.label("", "SmallLabel")
	l.custom_minimum_size.x = 250
	row.add_child(l)
	var bar := UI.progress(color, 14)
	row.add_child(bar)
	parent.add_child(row)
	return [l, bar]


func _build_active() -> PanelContainer:
	var card := UI.card()
	var v := UI.vbox(12)
	card.add_child(v)
	var top := UI.hbox()
	top.add_child(UI.label("Aktueller Auftrag", "MutedLabel"))
	top.add_child(UI.spacer())
	_order_badge = UI.badge("", UiTheme.ACCENT)
	top.add_child(_order_badge)
	v.add_child(top)
	_order_name = UI.label("", "TitleLabel")
	v.add_child(_order_name)
	_order_bar = UI.progress(UiTheme.ACCENT, 26)
	v.add_child(_order_bar)
	var info := UI.hbox()
	_order_work = UI.label("", "MutedLabel")
	info.add_child(_order_work)
	info.add_child(UI.spacer())
	_order_reward = UI.label("", "SmallLabel")
	info.add_child(_order_reward)
	v.add_child(info)
	_work_button = UI.button("Schrauben!", _on_work_pressed, "BigButton")
	_work_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_work_button.custom_minimum_size.y = 150
	_work_button.resized.connect(func() -> void: _work_button.pivot_offset = _work_button.size / 2.0)
	v.add_child(_work_button)
	return card


func _build_apprentice() -> PanelContainer:
	var card := UI.card()
	var v := UI.vbox(8)
	card.add_child(v)
	var top := UI.hbox()
	top.add_child(UI.label("Lehrling", "SubtitleLabel"))
	top.add_child(UI.spacer())
	_apprentice_rate = UI.label("", "MutedLabel")
	_apprentice_rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_apprentice_rate)
	v.add_child(top)
	_apprentice_order = UI.label("", "SmallLabel")
	v.add_child(_apprentice_order)
	_apprentice_bar = UI.progress(UiTheme.kind_color("quick"), 14)
	v.add_child(_apprentice_bar)
	return card


func _rebuild_board() -> void:
	for child in _board_box.get_children():
		_board_box.remove_child(child)
		child.queue_free()
	_board_rows.clear()
	for i in model.board.size():
		var order: Dictionary = model.board[i]
		var tpl := GameModel.order_template(order)
		var card := UI.card()
		var row := UI.hbox(14)
		card.add_child(row)
		var info := UI.vbox(6)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UI.label(tpl["name"], "SubtitleLabel"))
		var meta := UI.hbox(10)
		meta.add_child(UI.badge(Balance.KIND_NAMES[tpl["kind"]], UiTheme.kind_color(tpl["kind"])))
		meta.add_child(UI.label("%s Arbeit" % NumberFormat.num(model.order_work(order), 0), "MutedLabel"))
		info.add_child(meta)
		var reward := UI.label("", "SmallLabel")
		info.add_child(reward)
		var accept := UI.button("Annehmen", _on_accept.bind(i))
		accept.custom_minimum_size = Vector2(190, 88)
		accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(accept)
		_board_box.add_child(card)
		_board_rows.append({"order": order, "reward": reward, "button": accept})


func refresh() -> void:
	_refresh_goal()
	_refresh_active()
	_refresh_apprentice()
	_tier_label.text = "Kundschaft: " + Balance.CUSTOMER_TIERS[model.customer_tier()]["name"]
	var busy := not model.active_order.is_empty()
	_active_card.visible = busy
	_board_section.visible = not busy
	var locked := Time.get_ticks_msec() < _board_locked_until
	for row in _board_rows:
		row["reward"].text = _reward_text(row["order"])
		row["button"].disabled = busy or locked


func _refresh_goal() -> void:
	var def := model.phase_def()
	var rep_goal := float(def["goal_rep"])
	var money_goal := float(def["goal_money"])
	_goal_title.text = "Ziel: " + str(def["goal_title"])
	_goal_rep_label.text = "%s / %s Ruf" % [NumberFormat.big(model.reputation), NumberFormat.num(rep_goal, 0)]
	_goal_rep_bar.value = clampf(model.reputation.to_float() / rep_goal, 0.0, 1.0)
	_goal_money_label.text = "%s / %s" % [NumberFormat.money(model.money), NumberFormat.money(BigNumber.of(money_goal))]
	_goal_money_bar.value = clampf(model.money.to_float() / money_goal, 0.0, 1.0)
	_goal_button.visible = model.phase_goal_met()
	if model.can_advance_phase():
		_goal_button.text = str(def["goal_title"])
		_goal_button.disabled = false
	else:
		_goal_button.text = "Ziel erreicht – Phase %d folgt bald" % (model.phase + 1)
		_goal_button.disabled = true


func _refresh_active() -> void:
	var order := model.active_order
	if order.is_empty():
		return
	var tpl := GameModel.order_template(order)
	var work := model.order_work(order)
	_order_name.text = tpl["name"]
	UI.set_badge(_order_badge, Balance.KIND_NAMES[tpl["kind"]], UiTheme.kind_color(tpl["kind"]))
	_order_bar.value = model.active_progress / work
	_order_work.text = "%s / %s Arbeit" % [NumberFormat.num(model.active_progress, 0), NumberFormat.num(work, 0)]
	_order_reward.text = _reward_text(order)


func _refresh_apprentice() -> void:
	var level := model.upgrade_level("apprentice")
	_apprentice_card.visible = level > 0
	if level == 0:
		return
	_apprentice_rate.text = "%s Arbeit/s" % NumberFormat.num(model.apprentice_rate())
	var order := model.apprentice_order
	if order.is_empty():
		_apprentice_order.text = "Wartet auf Arbeit"
		_apprentice_bar.value = 0.0
		return
	var tpl := GameModel.order_template(order)
	_apprentice_order.text = "%s  ·  +%s" % [tpl["name"], NumberFormat.money(model.order_reward(order)["money"])]
	_apprentice_bar.value = model.apprentice_progress / model.order_work(order)


func _reward_text(order: Dictionary) -> String:
	var reward := model.order_reward(order)
	var parts := PackedStringArray([
		"+" + NumberFormat.money(reward["money"]),
		"+%s Ruf" % NumberFormat.num(reward["rep"].to_float(), 1),
	])
	if not reward["knowhow"].is_zero():
		parts.append("+%s Know-how" % NumberFormat.big(reward["knowhow"]))
	return "  ·  ".join(parts)


func _on_accept(index: int) -> void:
	model.accept_order(index)


func _on_goal_pressed() -> void:
	model.advance_phase()


func _on_work_pressed() -> void:
	if model.active_order.is_empty():
		return
	var power := model.tap_power()
	var reward := model.tap()
	_bump()
	if reward.is_empty():
		var jitter := Vector2(randf_range(-150.0, 150.0), randf_range(-30.0, 10.0))
		UI.float_text(fx, _center_of(_work_button) + jitter, "+" + NumberFormat.num(power, 1), UiTheme.MUTED, 26)


func _on_order_completed(_order: Dictionary, reward: Dictionary, by_apprentice: bool) -> void:
	if not is_visible_in_tree():
		return
	if by_apprentice:
		UI.float_text(fx, _center_of(_apprentice_card), "+" + NumberFormat.money(reward["money"]), UiTheme.MONEY, 26)
		return
	_board_locked_until = Time.get_ticks_msec() + 400
	var center := _center_of(_work_button)
	UI.float_text(fx, center, "+" + NumberFormat.money(reward["money"]), UiTheme.MONEY, 38)
	UI.float_text(fx, center + Vector2(0, 46), "+%s Ruf" % NumberFormat.num(reward["rep"].to_float(), 1), UiTheme.REPUTATION, 30)
	if not reward["knowhow"].is_zero():
		UI.float_text(fx, center + Vector2(0, 90), "+%s Know-how" % NumberFormat.big(reward["knowhow"]), UiTheme.KNOWHOW, 30)


func _bump() -> void:
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	_work_button.scale = Vector2(0.96, 0.96)
	_bump_tween = _work_button.create_tween()
	_bump_tween.tween_property(_work_button, "scale", Vector2.ONE, 0.12)


static func _center_of(c: Control) -> Vector2:
	return c.global_position + c.size / 2.0
