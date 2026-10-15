class_name OptionsPage
extends Page
## Optionen: Spielstand speichern, exportieren, importieren, zurücksetzen.


func _build() -> void:
	content.add_child(UI.label("Optionen", "TitleLabel"))

	var save := UI.card()
	var sv := UI.vbox(12)
	save.add_child(sv)
	sv.add_child(UI.label("Spielstand", "SubtitleLabel"))
	sv.add_child(UI.label("Wird automatisch alle %d Sekunden und beim Schließen gespeichert. Der Export-Text lässt sich auf einem anderen Gerät wieder importieren." % int(Balance.AUTOSAVE_SECONDS), "MutedLabel", true))
	sv.add_child(_wide(UI.button("Jetzt speichern", _save, "SecondaryButton")))
	sv.add_child(_wide(UI.button("Exportieren (Zwischenablage)", _export, "SecondaryButton")))
	sv.add_child(_wide(UI.button("Importieren", _open_import, "SecondaryButton")))
	content.add_child(save)

	var danger := UI.card()
	var dv := UI.vbox(12)
	danger.add_child(dv)
	dv.add_child(UI.label("Alles zurücksetzen", "SubtitleLabel"))
	dv.add_child(UI.label("Löscht den kompletten Spielstand inklusive Legende.", "MutedLabel", true))
	dv.add_child(_wide(UI.button("Spielstand löschen", _confirm_reset, "DangerButton")))
	content.add_child(danger)

	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	content.add_child(UI.label("Gear Up! %s · Hobbyprojekt" % version, "MutedLabel"))


func _wide(b: Button) -> Button:
	b.custom_minimum_size.y = 80
	return b


func _save() -> void:
	Game.save_game()
	UI.toast(fx, "Gespeichert")


func _export() -> void:
	DisplayServer.clipboard_set(Game.export_string())
	UI.toast(fx, "Spielstand in die Zwischenablage kopiert")


func _open_import() -> void:
	var box := UI.vbox(10)
	var input := TextEdit.new()
	input.custom_minimum_size.y = 200
	input.placeholder_text = "Export-Text hier einfügen"
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(input)
	var paste := UI.button("Aus Zwischenablage einfügen", func() -> void: input.text = DisplayServer.clipboard_get(), "SecondaryButton")
	paste.custom_minimum_size.y = 70
	box.add_child(paste)
	Modal.open(fx, "Spielstand importieren", "Der aktuelle Spielstand wird dabei überschrieben.", [
		{"text": "Abbrechen", "variation": "SecondaryButton"},
		{"text": "Laden", "callback": func() -> void: _import(input.text)},
	], box)


func _import(text: String) -> void:
	if Game.import_string(text):
		UI.toast(fx, "Spielstand geladen", UiTheme.MONEY)
	else:
		UI.toast(fx, "Kein gültiger Spielstand", UiTheme.DANGER)


func _confirm_reset() -> void:
	Modal.open(fx, "Wirklich alles löschen?", "Geld, Ruf, Know-how, Ausbau und Legende gehen verloren. Das lässt sich nicht rückgängig machen.", [
		{"text": "Abbrechen", "variation": "SecondaryButton"},
		{"text": "Löschen", "variation": "DangerButton", "callback": _reset},
	])


func _reset() -> void:
	Game.hard_reset()
	UI.toast(fx, "Neues Spiel gestartet")
