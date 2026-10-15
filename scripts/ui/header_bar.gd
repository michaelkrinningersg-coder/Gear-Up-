class_name HeaderBar
extends PanelContainer
## Kopfzeile: Phase, Legende-Bonus und die drei Run-Währungen.

var _phase: Label
var _legend: Label
var _money: Label
var _rep: Label
var _knowhow: Label


func _init() -> void:
	var v := UI.vbox(10)
	add_child(v)
	var top := UI.hbox()
	v.add_child(top)
	_phase = UI.label("", "MutedLabel")
	top.add_child(_phase)
	top.add_child(UI.spacer())
	_legend = UI.tint(UI.label("", "MutedLabel"), UiTheme.LEGEND)
	top.add_child(_legend)
	var row := UI.hbox(8)
	v.add_child(row)
	_money = _chip(row, "money", 1.3)
	_rep = _chip(row, "reputation", 1.0)
	_knowhow = _chip(row, "knowhow", 1.0)


func _chip(row: HBoxContainer, icon_name: String, ratio: float) -> Label:
	var chip := UI.hbox(8)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.size_flags_stretch_ratio = ratio
	chip.add_child(UI.icon(icon_name, 40))
	var value := UI.label("0", "ValueLabel")
	value.clip_text = true
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_child(value)
	row.add_child(chip)
	return value


func refresh(model: GameModel) -> void:
	_phase.text = "Phase %d · %s" % [model.phase, model.phase_def()["name"]]
	_money.text = NumberFormat.money(model.money)
	_rep.text = NumberFormat.big(model.reputation)
	_knowhow.text = NumberFormat.big(model.knowhow)
	if model.legend.is_zero():
		_legend.text = ""
	else:
		_legend.text = "Legende %s · ×%s" % [NumberFormat.big(model.legend), NumberFormat.num(model.legend_mult())]
