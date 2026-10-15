class_name LegendPage
extends Page
## Legende und Prestige: dauerhafter Fortschritt über alle Runs.

var _legend_value: Label
var _legend_bonus: Label
var _pending: Label
var _prestige_button: Button
var _run_money: Label
var _run_time: Label
var _run_orders: Label
var _total_prestiges: Label
var _total_money: Label
var _total_orders: Label
var _total_taps: Label
var _total_time: Label


func _build() -> void:
	content.add_child(UI.label("Legende", "TitleLabel"))

	var summary := UI.card()
	var row := UI.hbox(18)
	summary.add_child(row)
	row.add_child(UI.icon("legend", 72))
	var values := UI.vbox(2)
	row.add_child(values)
	_legend_value = UI.tint(UI.label("", "BigValueLabel"), UiTheme.LEGEND)
	values.add_child(_legend_value)
	_legend_bonus = UI.label("", "MutedLabel")
	values.add_child(_legend_bonus)
	content.add_child(summary)

	var prestige := UI.card()
	var pv := UI.vbox(12)
	prestige.add_child(pv)
	pv.add_child(UI.label("Prestige: Neustart als Schrauber", "SubtitleLabel"))
	pv.add_child(UI.label("Geld, Ruf, Know-how, Ausbau und Know-how-Baum werden zurückgesetzt. Legende bleibt und macht jeden Run schneller.", "SmallLabel", true))
	_pending = UI.label("", "SubtitleLabel", true)
	pv.add_child(_pending)
	pv.add_child(UI.label("Legende = %s × √(Gesamtgeld des Runs). Am meisten lohnt sich der erste Prestige ab Phase 3 (Radmarke)." % NumberFormat.num(Balance.LEGEND_K), "MutedLabel", true))
	_prestige_button = UI.button("Prestige", _confirm_prestige)
	_prestige_button.custom_minimum_size.y = 80
	pv.add_child(_prestige_button)
	content.add_child(prestige)

	var run := UI.card()
	var rv := UI.vbox(8)
	run.add_child(rv)
	rv.add_child(UI.label("Dieser Run", "SubtitleLabel"))
	_run_money = UI.stat_row(rv, "Gesamtgeld")
	_run_orders = UI.stat_row(rv, "Aufträge")
	_run_time = UI.stat_row(rv, "Spielzeit")
	content.add_child(run)

	var total := UI.card()
	var tv := UI.vbox(8)
	total.add_child(tv)
	tv.add_child(UI.label("Insgesamt", "SubtitleLabel"))
	_total_prestiges = UI.stat_row(tv, "Prestiges")
	_total_money = UI.stat_row(tv, "Geld verdient")
	_total_orders = UI.stat_row(tv, "Aufträge")
	_total_taps = UI.stat_row(tv, "Tipps")
	_total_time = UI.stat_row(tv, "Spielzeit")
	content.add_child(total)

	content.add_child(UI.label("Perk-Baum (Gründer, Automatik, Erbe), Erfolge und Challenges folgen in späteren Meilensteinen.", "MutedLabel", true))


func refresh() -> void:
	_legend_value.text = NumberFormat.big(model.legend)
	_legend_bonus.text = "+%s auf Geld und Ruf" % NumberFormat.percent(model.legend_mult() - 1.0)
	var pending := model.pending_legend()
	_pending.text = "Beim Neustart: +%s Legende" % NumberFormat.big(pending)
	_prestige_button.disabled = not model.can_prestige()
	_run_money.text = NumberFormat.money(model.run_money)
	_run_orders.text = NumberFormat.num(model.run_orders, 0)
	_run_time.text = NumberFormat.duration(model.run_time)
	_total_prestiges.text = str(model.prestige_count)
	_total_money.text = NumberFormat.money(model.lifetime_money)
	_total_orders.text = NumberFormat.num(model.total_orders, 0)
	_total_taps.text = NumberFormat.num(model.total_taps, 0)
	_total_time.text = NumberFormat.duration(model.total_time)


func _confirm_prestige() -> void:
	var gained := model.pending_legend()
	var after := 1.0 + Balance.LEGEND_BONUS_PER_POINT * model.legend.add(gained).to_float()
	var body := "Du startest wieder als Schrauber und erhältst +%s Legende. Danach gilt +%s auf Geld und Ruf." % [
		NumberFormat.big(gained), NumberFormat.percent(after - 1.0)]
	Modal.open(fx, "Neu anfangen?", body, [
		{"text": "Abbrechen", "variation": "SecondaryButton"},
		{"text": "Neustart", "callback": _do_prestige},
	])


func _do_prestige() -> void:
	var gained := Game.prestige()
	UI.toast(fx, "+%s Legende – auf ein Neues!" % NumberFormat.big(gained), UiTheme.LEGEND)
