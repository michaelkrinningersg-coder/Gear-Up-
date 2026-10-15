class_name SaveCodec
extends RefCounted
## Spielstand <-> JSON und Export-Text (Base64 mit Kennung zum Kopieren).

const VERSION := 1
const EXPORT_PREFIX := "GEARUP1:"


static func encode(model: GameModel, saved_at: float) -> Dictionary:
	return {"version": VERSION, "saved_at": saved_at, "model": model.to_dict()}


static func to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "", false, true)


## Liefert ein leeres Dictionary, wenn der Text kein gültiger Spielstand ist.
static func parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	if data is Dictionary and data.get("model") is Dictionary:
		return data
	return {}


static func to_export_string(data: Dictionary) -> String:
	return EXPORT_PREFIX + Marshalls.utf8_to_base64(to_json(data))


static func from_export_string(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if not trimmed.begins_with(EXPORT_PREFIX):
		return {}
	var payload := trimmed.substr(EXPORT_PREFIX.length())
	if payload.is_empty():
		return {}
	return parse_json(Marshalls.base64_to_utf8(payload))
