class_name BrandPage
extends Page
## Radmarke (Phase 3): Modelle entwickeln, Preisklasse wählen, Marktanteil gewinnen.

var _summary: Label
var _share_bar: ProgressBar
var _dev_card: PanelContainer
var _dev_title: Label
var _dev_bar: ProgressBar
var _dev_info: Label
var _design_button: Button
var _bump_tween: Tween
var _rows := {}
var _share_title: Label
var _region_section: VBoxContainer
var _region_rows := {}


func _build() -> void:
	content.add_child(UI.label("Radmarke", "TitleLabel"))
	var overview := UI.card()
	var ov := UI.vbox(10)
	overview.add_child(ov)
	var share_row := UI.hbox(10)
	_share_title = UI.label("Marktanteil Heimatland", "SubtitleLabel")
	share_row.add_child(_share_title)
	ov.add_child(share_row)
	_share_bar = UI.progress(UiTheme.ACCENT, 16)
	ov.add_child(_share_bar)
	_summary = UI.label("", "MutedLabel", true)
	ov.add_child(_summary)
	content.add_child(overview)

	_dev_card = UI.card()
	var dv := UI.vbox(12)
	_dev_card.add_child(dv)
	dv.add_child(UI.label("In Entwicklung", "MutedLabel"))
	_dev_title = UI.label("", "TitleLabel")
	dv.add_child(_dev_title)
	_dev_bar = UI.progress(UiTheme.KNOWHOW, 24)
	dv.add_child(_dev_bar)
	_dev_info = UI.label("", "MutedLabel")
	dv.add_child(_dev_info)
	_design_button = UI.button("Konstruieren!", _on_design_pressed, "BigButton")
	_design_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_design_button.custom_minimum_size.y = 130
	_design_button.resized.connect(func() -> void: _design_button.pivot_offset = _design_button.size / 2.0)
	dv.add_child(_design_button)
	content.add_child(_dev_card)

	_region_section = UI.vbox(14)
	_region_section.add_child(UI.label("Regionen", "TitleLabel"))
	_region_section.add_child(UI.label("Jede Region mag andere Sparten. Kampagnen machen deine Räder dort für eine Weile attraktiver (höchstens %d gleichzeitig)." % Balance.CAMPAIGN_SLOTS, "MutedLabel", true))
	for r in Balance.REGIONS:
		_region_section.add_child(_build_region_row(r))
	content.add_child(_region_section)

	content.add_child(UI.label("Sparten", "TitleLabel"))
	for s in Balance.SPARTEN:
		content.add_child(_build_row(s))
	model.model_developed.connect(_on_model_developed)


func _build_row(s: Dictionary) -> PanelContainer:
	var card := UI.card()
	var v := UI.vbox(10)
	card.add_child(v)
	var head := UI.hbox(12)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(s["name"], "SubtitleLabel"))
	var gen := UI.label("", "MutedLabel")
	info.add_child(gen)
	head.add_child(info)
	var develop := UI.button("", _on_develop.bind(s["id"]))
	develop.icon = UI.icon_texture("money")
	develop.custom_minimum_size = Vector2(230, 84)
	develop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(develop)
	v.add_child(head)
	var classes := UI.hbox(8)
	var class_buttons: Array[Button] = []
	for i in Balance.PRICE_CLASSES.size():
		var b := UI.button(Balance.PRICE_CLASSES[i]["name"], _on_class.bind(s["id"], i), "SecondaryButton")
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size.y = 60
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		classes.add_child(b)
		class_buttons.append(b)
	v.add_child(classes)
	var stats := UI.label("", "SmallLabel", true)
	v.add_child(stats)
	_rows[s["id"]] = {"gen": gen, "develop": develop, "classes": classes, "class_buttons": class_buttons, "stats": stats, "class": -1}
	return card


func _build_region_row(r: Dictionary) -> PanelContainer:
	var card := UI.card()
	var row := UI.hbox(12)
	card.add_child(row)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(r["name"], "SubtitleLabel"))
	var likes := PackedStringArray()
	for sid in r["prefs"]:
		if float(r["prefs"][sid]) > 1.0:
			likes.append(Balance.sparte(sid)["name"])
	info.add_child(UI.label("Mag: " + (", ".join(likes) if not likes.is_empty() else "alles gleich"), "MutedLabel", true))
	var status := UI.label("", "SmallLabel")
	info.add_child(status)
	var campaign_bar := UI.progress(UiTheme.LEGEND, 8)
	info.add_child(campaign_bar)
	row.add_child(info)
	var action := UI.button("", _on_region_action.bind(r["id"]))
	action.icon = UI.icon_texture("money")
	action.custom_minimum_size = Vector2(230, 96)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	_region_rows[r["id"]] = {"status": status, "action": action, "bar": campaign_bar}
	return card


func _refresh_regions(rates: Dictionary) -> void:
	_region_section.visible = model.national_open()
	if not model.national_open():
		return
	for r in Balance.REGIONS:
		var rid: String = r["id"]
		var row: Dictionary = _region_rows[rid]
		var action: Button = row["action"]
		var size := model.region_market_size(rid)
		var time_left := model.campaign_time_left(rid)
		row["bar"].visible = time_left > 0.0
		row["bar"].value = time_left / model.campaign_duration()
		if not model.region_open(rid):
			row["status"].text = "Markt %s Räder/s · nicht erschlossen" % NumberFormat.num(size, 0)
			action.text = "Erschließen\n" + NumberFormat.money(model.region_cost(rid))
			action.disabled = not model.can_open_region(rid)
			continue
		var sold := float(rates["regions"].get(rid, 0.0))
		row["status"].text = "Anteil %s · %s Räder/s" % [NumberFormat.percent(sold / size), NumberFormat.num(sold)]
		if time_left > 0.0:
			action.text = "Kampagne\n%s" % NumberFormat.duration(time_left)
			action.icon = null
			action.disabled = true
		else:
			action.text = "Kampagne\n" + NumberFormat.money(model.campaign_cost(rid))
			action.icon = UI.icon_texture("money")
			action.disabled = not model.can_start_campaign(rid)


func _on_region_action(region_id: String) -> void:
	if not model.region_open(region_id):
		if model.open_region(region_id):
			UI.toast(fx, "%s erschlossen!" % Balance.region(region_id)["name"], UiTheme.MONEY)
	elif model.start_campaign(region_id):
		UI.toast(fx, "Kampagne in %s gestartet" % Balance.region(region_id)["name"], UiTheme.LEGEND)


func refresh() -> void:
	var rates := model.brand_rates()
	_share_title.text = "Marktanteil Inland" if model.national_open() else "Marktanteil Heimatland"
	_refresh_regions(rates)
	var goal := float(model.phase_def().get("goal_share", 0.0))
	var share := model.market_share()
	_share_bar.value = clampf(share / goal, 0.0, 1.0) if goal > 0.0 else share
	_summary.text = "%s von %s Ziel · %s Räder/s von %s produzierbar · Gewinn %s/s · Reichweite %s" % [
		NumberFormat.percent(share), NumberFormat.percent(goal),
		NumberFormat.num(rates["total_units"]), NumberFormat.num(model.production_capacity()),
		NumberFormat.money(BigNumber.of(rates["profit"])), NumberFormat.percent(model.brand_reach())]

	var project := model.dev_project
	_dev_card.visible = not project.is_empty()
	if not project.is_empty():
		var sid: String = project["sparte"]
		var next := model.generation(sid) + 1
		var work := model.dev_work(sid)
		_dev_title.text = "%s Gen %d · %s" % [Balance.sparte(sid)["name"], next, Balance.MATERIALS[next - 1]]
		_dev_bar.value = float(project["work"]) / work
		_dev_info.text = "%s / %s Entwicklung · Büro %s/s" % [
			NumberFormat.num(project["work"], 0), NumberFormat.num(work, 0), NumberFormat.num(model.design_rate(), 1)]

	for s in Balance.SPARTEN:
		var row: Dictionary = _rows[s["id"]]
		var sid: String = s["id"]
		var gen := model.generation(sid)
		var develop: Button = row["develop"]
		row["classes"].visible = gen > 0
		if gen > 0:
			row["gen"].text = "Gen %d · %s" % [gen, Balance.MATERIALS[gen - 1]]
			row["stats"].text = "Preis %s · Stückkosten %s · Anteil %s · %s Räder/s" % [
				NumberFormat.money(BigNumber.of(model.brand_price(sid))),
				NumberFormat.money(BigNumber.of(model.brand_unit_cost(sid))),
				NumberFormat.percent(model.brand_appeal_share(sid) * model.brand_reach()),
				NumberFormat.num(rates["units"][sid])]
		else:
			row["gen"].text = "Noch kein Modell"
			row["stats"].text = "Markt: %s Räder/s · Konkurrenz: %s" % [
				NumberFormat.num(s["market"], 0), Balance.BRAND_COMPETITORS[Balance.SPARTEN.find(s) % Balance.BRAND_COMPETITORS.size()]]
		var cls := model.price_class(sid)
		if row["class"] != cls:
			row["class"] = cls
			var buttons: Array[Button] = row["class_buttons"]
			for i in buttons.size():
				buttons[i].theme_type_variation = "Button" if i == cls else "SecondaryButton"
		if not model.sparte_unlocked(sid):
			develop.text = "E-Antrieb nötig"
			develop.icon = null
			develop.disabled = true
		elif gen >= Balance.MATERIALS.size():
			develop.text = "Ausentwickelt"
			develop.icon = null
			develop.disabled = true
		elif gen >= model.max_generation():
			develop.text = "%s nötig" % Balance.MATERIALS[gen]
			develop.icon = null
			develop.disabled = true
		else:
			develop.text = NumberFormat.money(model.dev_cost(sid))
			develop.icon = UI.icon_texture("money")
			develop.disabled = not model.can_start_dev(sid)


func _on_develop(sparte_id: String) -> void:
	model.start_dev(sparte_id)


func _on_class(sparte_id: String, index: int) -> void:
	model.set_price_class(sparte_id, index)


func _on_design_pressed() -> void:
	if not model.design_tap():
		return
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	_design_button.scale = Vector2(0.96, 0.96)
	_bump_tween = _design_button.create_tween()
	_bump_tween.tween_property(_design_button, "scale", Vector2.ONE, 0.12)
	var center := _design_button.global_position + _design_button.size / 2.0
	var jitter := Vector2(randf_range(-150.0, 150.0), randf_range(-30.0, 10.0))
	UI.float_text(fx, center + jitter, "+" + NumberFormat.num(model.tap_power(), 1), UiTheme.MUTED, 26)


func _on_model_developed(sparte_id: String, gen: int) -> void:
	UI.toast(fx, "Neues Modell: %s Gen %d · %s (+%s Know-how)" % [
		Balance.sparte(sparte_id)["name"], gen, Balance.MATERIALS[gen - 1],
		NumberFormat.num(Balance.DEV_KNOWHOW * gen, 0)], UiTheme.KNOWHOW)
