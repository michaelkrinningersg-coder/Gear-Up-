extends Control
## Hauptbildschirm: Kopfzeile, Seiten und Navigation unten (Daumenreichweite).

const PAGES := [
	["Werkstatt", "nav_workshop"],
	["Laden", "nav_shop"],
	["Marke", "nav_brand"],
	["Ausbau", "nav_upgrades"],
	["Know-how", "nav_knowhow"],
	["Legende", "nav_legend"],
]
const SHOP_PAGE := 1
const BRAND_PAGE := 2
## Optionen haben keinen Tab, sondern das Zahnrad in der Kopfzeile.
const OPTIONS_PAGE := 6

var _header: HeaderBar
var _pages: Array[Page] = []
var _nav: Array[Button] = []
var _current := 0
var _last_phase := 1
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
	_header.options_pressed.connect(func() -> void: _show_page(OPTIONS_PAGE))
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
	_pages = [WorkshopPage.new(), ShopPage.new(), BrandPage.new(), UpgradesPage.new(), KnowhowPage.new(), LegendPage.new(), OptionsPage.new()]
	for page in _pages:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(page)
		page.setup(model, _fx)
	_show_page(0)

	model.customer_tier_changed.connect(_on_tier_changed)
	_last_phase = model.phase
	model.phase_changed.connect(_on_phase_changed)
	Game.offline_progress.connect(_show_offline_report)
	if not Game.offline_report.is_empty():
		_show_offline_report.call_deferred(Game.offline_report)


func _process(_delta: float) -> void:
	_nav[SHOP_PAGE].visible = Game.model.shop_open()
	_nav[BRAND_PAGE].visible = Game.model.brand_open()
	if _current < _nav.size() and not _nav[_current].visible:
		_show_page(0)
	_header.refresh(Game.model)
	_pages[_current].refresh()


func _build_nav() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NavBar"
	var row := UI.hbox(4)
	bar.add_child(row)
	var group := ButtonGroup.new()
	group.allow_unpress = true
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
	for i in _nav.size():
		_nav[i].set_pressed_no_signal(i == index)
	_pages[index].refresh()


func _on_phase_changed() -> void:
	var phase := Game.model.phase
	if phase > _last_phase:
		UI.toast(_fx, "Phase %d: %s – geschafft!" % [phase, Balance.phase_def(phase)["name"]], UiTheme.MONEY)
		if phase == 2:
			_show_page(SHOP_PAGE)
		elif phase == 3:
			_show_page(BRAND_PAGE)
	_last_phase = phase


func _on_tier_changed(tier: int) -> void:
	UI.toast(_fx, "Neue Kundschaft: %s – größere Aufträge, mehr Lohn!" % Balance.CUSTOMER_TIERS[tier]["name"], UiTheme.REPUTATION)


func _show_offline_report(report: Dictionary) -> void:
	Game.offline_report = {}
	var work := PackedStringArray()
	if int(report["orders"]) > 0:
		work.append("dein Lehrling %s Aufträge erledigt" % NumberFormat.num(report["orders"], 0))
	if int(report.get("sales", 0)) > 0:
		work.append("dein Verkäufer %s Räder verkauft" % NumberFormat.num(report["sales"], 0))
	if int(report.get("bikes", 0)) > 0:
		work.append("deine Marke %s Räder abgesetzt" % NumberFormat.num(report["bikes"], 0))
	var body := "Du warst %s weg. In der Zeit hat mit halber Kraft %s:\n\n+%s   ·   +%s Ruf" % [
		NumberFormat.duration(report["seconds"]),
		" und ".join(work),
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
