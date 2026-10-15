class_name UI
extends RefCounted
## Kleine Bausteine für die Oberfläche, damit die Seiten kompakt bleiben.

const ICON_DIR := "res://assets/icons/"


static func card() -> PanelContainer:
	var c := PanelContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func vbox(separation := 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func hbox(separation := 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func label(text := "", variation := "", wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func tint(l: Label, color: Color) -> Label:
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_pressed: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


static func progress(color: Color, height := 16) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.min_value = 0.0
	p.max_value = 1.0
	p.step = 0.0
	p.custom_minimum_size.y = height
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("background", UiTheme.box(UiTheme.TRACK, floori(height / 2.0), 0))
	p.add_theme_stylebox_override("fill", UiTheme.box(color, floori(height / 2.0), 0))
	return p


static func icon_texture(icon_name: String) -> Texture2D:
	return load(ICON_DIR + icon_name + ".svg")


static func icon(icon_name: String, size := 36) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Farbiges Etikett, z. B. „Lukrativ".
static func badge(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(label("", "MutedLabel"))
	set_badge(p, text, color)
	return p


static func set_badge(badge_panel: PanelContainer, text: String, color: Color) -> void:
	var l := badge_panel.get_child(0) as Label
	if l.text == text and badge_panel.has_meta("color") and badge_panel.get_meta("color") == color:
		return
	l.text = text
	tint(l, color)
	var style := UiTheme.box(Color(color, 0.13), 10, 0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	badge_panel.add_theme_stylebox_override("panel", style)
	badge_panel.set_meta("color", color)


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Zeile „Name ........ Wert" für Statistiken. Liefert das Wert-Label.
static func stat_row(parent: Control, title: String) -> Label:
	var row := hbox()
	row.add_child(label(title, "MutedLabel"))
	row.add_child(spacer())
	var value := label("", "SmallLabel")
	row.add_child(value)
	parent.add_child(row)
	return value


## Schwebender Text, z. B. „+12 €" über dem Schrauben-Knopf.
static func float_text(layer: Control, global_pos: Vector2, text: String, color: Color, font_size := 30) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 8)
	layer.add_child(l)
	l.reset_size()
	l.global_position = global_pos - l.size / 2.0
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 110.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(l.queue_free)


## Kurze Einblendung oben, z. B. „Gespeichert".
static func toast(layer: Control, text: String, color := UiTheme.TEXT) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.box(color, 18, 18))
	var l := tint(label(text, "SmallLabel"), Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	layer.add_child(p)
	p.reset_size()
	p.position = Vector2((layer.size.x - p.size.x) / 2.0, 170.0)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
