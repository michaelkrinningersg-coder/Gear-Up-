extends Node
## Autoload „Game": hält das Spielmodell, tickt es, speichert automatisch
## und verrechnet die Zeit, in der das Spiel geschlossen war.

signal offline_progress(report: Dictionary)

const SAVE_PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.bak.json"
const MAX_TICK_SECONDS := 1.0

var model := GameModel.new()
## Bericht über Offline-Fortschritt beim Start; die Oberfläche zeigt ihn an und leert ihn.
var offline_report: Dictionary = {}

var _autosave_timer := 0.0
var _paused_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func _process(delta: float) -> void:
	# Lange Pausen (App im Hintergrund) laufen über den Offline-Fortschritt,
	# sonst würde ein großer erster Frame danach doppelt zählen.
	model.tick(minf(delta, MAX_TICK_SECONDS))
	_autosave_timer += delta
	if _autosave_timer >= Balance.AUTOSAVE_SECONDS:
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			save_game()
		NOTIFICATION_APPLICATION_PAUSED:
			save_game()
			_paused_at = _now()
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at > 0.0:
				_apply_offline(_now() - _paused_at)
				_paused_at = 0.0


func save_game() -> void:
	_autosave_timer = 0.0
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(SaveCodec.to_json(SaveCodec.encode(model, _now())))
	file.close()
	# Erst den alten Stand als Sicherung behalten, dann den neuen an seine Stelle setzen.
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(BACKUP_PATH)
		DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
	DirAccess.rename_absolute(tmp_path, SAVE_PATH)


func export_string() -> String:
	return SaveCodec.to_export_string(SaveCodec.encode(model, _now()))


func import_string(text: String) -> bool:
	var data := SaveCodec.from_export_string(text)
	if data.is_empty():
		return false
	model.from_dict(data["model"])
	save_game()
	return true


func prestige() -> BigNumber:
	var gained := model.prestige()
	save_game()
	return gained


func hard_reset() -> void:
	model.wipe()
	save_game()


func _load() -> void:
	var data := _read(SAVE_PATH)
	if data.is_empty():
		data = _read(BACKUP_PATH)
	if data.is_empty():
		return
	model.from_dict(data["model"])
	var saved_at := float(data.get("saved_at", _now()))
	_apply_offline(_now() - saved_at)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return SaveCodec.parse_json(FileAccess.get_file_as_string(path))


func _apply_offline(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var report := model.apply_offline(seconds)
	if seconds >= Balance.OFFLINE_REPORT_MIN_SECONDS and int(report["orders"]) > 0:
		offline_report = report
		offline_progress.emit(report)


func _now() -> float:
	return Time.get_unix_time_from_system()
