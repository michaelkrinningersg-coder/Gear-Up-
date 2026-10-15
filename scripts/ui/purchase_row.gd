class_name PurchaseRow
extends PanelContainer
## Karte für Ausbaustufen und Know-how-Knoten: Name, Stufe, Effekt, Kauf-Knopf.

var _level: Label
var _effect: Label
var _button: Button
var _icon: Texture2D


func _init(title: String, description: String, on_buy: Callable, currency_icon: String) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(16)
	add_child(row)
	var info := UI.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var head := UI.hbox(12)
	head.add_child(UI.label(title, "SubtitleLabel"))
	_level = UI.label("", "MutedLabel")
	_level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_level)
	info.add_child(head)
	info.add_child(UI.label(description, "SmallLabel", true))
	_effect = UI.tint(UI.label("", "MutedLabel", true), UiTheme.ACCENT_PRESSED)
	info.add_child(_effect)
	_icon = UI.icon_texture(currency_icon)
	_button = UI.button("", on_buy)
	_button.icon = _icon
	_button.custom_minimum_size = Vector2(200, 92)
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_button)


func set_state(level_text: String, effect_text: String, button_text: String, enabled: bool, show_icon := true) -> void:
	_level.text = level_text
	_effect.text = effect_text
	_effect.visible = effect_text != ""
	_button.text = button_text
	_button.disabled = not enabled
	_button.icon = _icon if show_icon else null


## Effekttext aus der Datendefinition: „Gesamt: +3 Arbeit pro Tipp".
static func effect_text(def: Dictionary, level: int) -> String:
	if level <= 0:
		return ""
	var effect := str(def["effect"])
	if not effect.contains("%s"):
		return effect
	var total := level * float(def["value"]) * float(def.get("effect_scale", 1.0))
	return "Gesamt: " + (effect % NumberFormat.num(total))


static func level_text(def: Dictionary, level: int) -> String:
	var max_level := int(def.get("max_level", 0))
	if max_level > 0:
		return "Stufe %d/%d" % [level, max_level]
	return "Stufe %d" % level
