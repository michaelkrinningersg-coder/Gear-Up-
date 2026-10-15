extends Control
## Hauptbildschirm: Kopfzeile, Seiten und Navigation unten (Daumenreichweite).

const PAGES := [
	["Werkstatt", "nav_workshop"],
	["Ausbau", "nav_upgrades"],
	["Know-how", "nav_knowhow"],
	["Legende", "nav_legend"],
	["Optionen", "nav_options"],
]

var _header: HeaderBar
var _pages: Array[Page] = []
var _nav: Array[Button] = []
var _current := 0
## Ebene über allem für schwebende Texte, Toasts und Dialoge.
var _fx: Control


func _ready() -> void:
	theme = UiTheme.build()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := _safe_insets()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18 + int(insets.x))
	margin.add_theme_constant_override("margin_bottom", 14 + int(insets.y))
	add_child(margin)

	var column := UI.vbox(16)
	margin.add_child(column)
	_header = HeaderBar.new()
	column.add_child(_header)

	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.clip_contents = true
	column.add_child(stack)
	column.add_child(_build_nav())

	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)

	var model := Game.model
	_pages = [WorkshopPage.new(), UpgradesPage.new(), KnowhowPage.new(), LegendPage.new(), OptionsPage.new()]
	for page in _pages:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(page)
		page.setup(model, _fx)
	_show_page(0)

	model.customer_tier_changed.connect(_on_tier_changed)
	Game.offline_progress.connect(_show_offline_report)
	if not Game.offline_report.is_empty():
		_show_offline_report.call_deferred(Game.offline_report)


func _process(_delta: float) -> void:
	_header.refresh(Game.model)
	_pages[_current].refresh()


func _build_nav() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NavBar"
	var row := UI.hbox(4)
	bar.add_child(row)
	var group := ButtonGroup.new()
	for i in PAGES.size():
		var b := Button.new()
		b.theme_type_variation = "NavButton"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.text = PAGES[i][0]
		b.icon = UI.icon_texture(PAGES[i][1])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size.y = 96
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show_page.bind(i))
		row.add_child(b)
		_nav.append(b)
	return bar


func _show_page(index: int) -> void:
	_current = index
	for i in _pages.size():
		_pages[i].visible = i == index
	_nav[index].button_pressed = true
	_pages[index].refresh()


func _on_tier_changed(tier: int) -> void:
	UI.toast(_fx, "Neue Kundschaft: %s – größere Aufträge, mehr Lohn!" % Balance.CUSTOMER_TIERS[tier]["name"], UiTheme.REPUTATION)


func _show_offline_report(report: Dictionary) -> void:
	Game.offline_report = {}
	var body := "Du warst %s weg. Dein Lehrling hat in der Zeit mit halber Kraft %s Aufträge erledigt:\n\n+%s   ·   +%s Ruf" % [
		NumberFormat.duration(report["seconds"]),
		NumberFormat.num(report["orders"], 0),
		NumberFormat.money(report["money"]),
		NumberFormat.big(report["rep"]),
	]
	Modal.open(_fx, "Willkommen zurück!", body, [{"text": "Weiter"}])


## Ränder für Notch und Gestenleiste auf dem Handy (oben, unten) in Viewport-Pixeln.
func _safe_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	if window.y <= 0:
		return Vector2.ZERO
	var factor := get_viewport_rect().size.y / float(window.y)
	var top := float(safe.position.y) * factor
	var bottom := float(window.y - safe.end.y) * factor
	return Vector2(maxf(top, 0.0), maxf(bottom, 0.0))
