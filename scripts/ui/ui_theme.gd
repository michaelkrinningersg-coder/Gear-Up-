class_name UiTheme
extends RefCounted
## Clean Flat-UI: helle Karten, klare Farben, große Touch-Flächen.

const BG := Color("#f1ede6")
const CARD := Color("#ffffff")
const TEXT := Color("#1f2430")
const MUTED := Color("#77706a")
const LINE := Color("#e6e0d6")
const TRACK := Color("#ece6dc")
const ACCENT := Color("#e8590c")
const ACCENT_HOVER := Color("#f06d24")
const ACCENT_PRESSED := Color("#c44a08")
const SECONDARY := Color("#f3efe9")
const DISABLED_BG := Color("#e9e4dc")
const DISABLED_TEXT := Color("#aaa39a")
const DANGER := Color("#e03131")

const MONEY := Color("#2b8a3e")
const REPUTATION := Color("#e67700")
const KNOWHOW := Color("#1c7ed6")
const LEGEND := Color("#7048e8")

const KIND_COLORS := {
	"quick": Color("#1c7ed6"),
	"lucrative": Color("#2b8a3e"),
	"tricky": Color("#7048e8"),
}

const FONT_SIZE := 26
const FONT_SMALL := 22
const FONT_MUTED := 21
const FONT_SUBTITLE := 27
const FONT_TITLE := 33
const FONT_VALUE := 28
const FONT_BIG_VALUE := 52
const FONT_BIG_BUTTON := 40


static func kind_color(kind: String) -> Color:
	return KIND_COLORS.get(kind, ACCENT)


static func box(color: Color, radius := 18, padding := 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(padding)
	s.anti_aliasing = true
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7

	# Texte
	t.set_color("font_color", "Label", TEXT)
	_label(t, "TitleLabel", FONT_TITLE, TEXT, bold)
	_label(t, "SubtitleLabel", FONT_SUBTITLE, TEXT, bold)
	_label(t, "ValueLabel", FONT_VALUE, TEXT, bold)
	_label(t, "BigValueLabel", FONT_BIG_VALUE, TEXT, bold)
	_label(t, "SmallLabel", FONT_SMALL, TEXT, null)
	_label(t, "MutedLabel", FONT_MUTED, MUTED, null)

	# Karten
	var card := box(CARD, 22, 22)
	card.shadow_color = Color(0.25, 0.18, 0.1, 0.07)
	card.shadow_size = 8
	card.shadow_offset = Vector2(0, 3)
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_type_variation("NavBar", "PanelContainer")
	var nav_bar := box(CARD, 26, 8)
	nav_bar.shadow_color = card.shadow_color
	nav_bar.shadow_size = 10
	t.set_stylebox("panel", "NavBar", nav_bar)

	# Knöpfe
	t.set_font("font", "Button", bold)
	_button(t, "Button", ACCENT, ACCENT_HOVER, ACCENT_PRESSED, Color.WHITE)
	_button(t, "SecondaryButton", SECONDARY, Color("#ebe5dc"), Color("#e0d9ce"), TEXT)
	_button(t, "DangerButton", DANGER, Color("#f03e3e"), Color("#c92a2a"), Color.WHITE)
	_button(t, "BigButton", ACCENT, ACCENT_HOVER, ACCENT_PRESSED, Color.WHITE)
	t.set_font_size("font_size", "BigButton", FONT_BIG_BUTTON)
	t.set_constant("icon_max_width", "Button", 30)
	t.set_constant("h_separation", "Button", 10)
	_nav_button(t)

	# Fortschrittsbalken
	t.set_stylebox("background", "ProgressBar", box(TRACK, 10, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 10, 0))

	# Eingabefelder
	var field := box(Color("#f7f4ef"), 14, 14)
	field.border_color = LINE
	field.set_border_width_all(2)
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = ACCENT
	for type in ["TextEdit", "LineEdit"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("focus", type, field_focus)
		t.set_color("font_color", type, TEXT)
		t.set_font_size("font_size", type, FONT_SMALL)

	# Schmale Scrollleiste
	var grabber := box(Color(0, 0, 0, 0.16), 4, 0)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	return t


static func _label(t: Theme, type: String, size: int, color: Color, font: Font) -> void:
	t.set_type_variation(type, "Label")
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, color)
	if font != null:
		t.set_font("font", type, font)


static func _button(t: Theme, type: String, normal: Color, hover: Color, pressed: Color, font: Color) -> void:
	if type != "Button":
		t.set_type_variation(type, "Button")
	t.set_stylebox("normal", type, box(normal, 16, 16))
	t.set_stylebox("hover", type, box(hover, 16, 16))
	t.set_stylebox("pressed", type, box(pressed, 16, 16))
	t.set_stylebox("hover_pressed", type, box(pressed, 16, 16))
	t.set_stylebox("disabled", type, box(DISABLED_BG, 16, 16))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for item in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(item, type, font)
	t.set_color("font_disabled_color", type, DISABLED_TEXT)


static func _nav_button(t: Theme) -> void:
	var type := "NavButton"
	t.set_type_variation(type, "Button")
	var idle := box(Color(0, 0, 0, 0), 20, 10)
	var active := box(Color(ACCENT, 0.12), 20, 10)
	t.set_stylebox("normal", type, idle)
	t.set_stylebox("hover", type, idle)
	t.set_stylebox("pressed", type, active)
	t.set_stylebox("hover_pressed", type, active)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_font_size("font_size", type, 19)
	for item in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(item, type, MUTED)
	t.set_color("font_pressed_color", type, ACCENT)
	t.set_color("font_hover_pressed_color", type, ACCENT)
	for item in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		t.set_color(item, type, MUTED)
	t.set_color("icon_pressed_color", type, ACCENT)
	t.set_color("icon_hover_pressed_color", type, ACCENT)
	t.set_constant("icon_max_width", type, 40)
	t.set_constant("h_separation", type, 4)
