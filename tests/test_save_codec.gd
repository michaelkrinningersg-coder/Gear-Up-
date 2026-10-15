extends TestCase


func test_export_import_roundtrip() -> void:
	var m := GameModel.new(3)
	m.money = BigNumber.of(98765.0)
	m.legend = BigNumber.of(12.0)
	var text := SaveCodec.to_export_string(SaveCodec.encode(m, 1700000000.0))
	check(text.begins_with(SaveCodec.EXPORT_PREFIX), "Kennung vorne")
	var data := SaveCodec.from_export_string("  " + text + "\n")
	check(not data.is_empty(), "Export lässt sich lesen")
	check_eq(int(data["version"]), SaveCodec.VERSION, "Version")
	check_near(float(data["saved_at"]), 1700000000.0, 1e-12, "Zeitstempel")
	var copy := GameModel.new(4)
	copy.from_dict(data["model"])
	check(copy.money.cmp(m.money) == 0, "Geld übernommen")
	check(copy.legend.cmp(m.legend) == 0, "Legende übernommen")


func test_rejects_invalid_text() -> void:
	check(SaveCodec.from_export_string("").is_empty(), "Leerer Text")
	check(SaveCodec.from_export_string("Hallo Welt").is_empty(), "Ohne Kennung")
	check(SaveCodec.from_export_string(SaveCodec.EXPORT_PREFIX).is_empty(), "Nur Kennung")
	var no_model := SaveCodec.EXPORT_PREFIX + Marshalls.utf8_to_base64("{\"version\": 1}")
	check(SaveCodec.from_export_string(no_model).is_empty(), "JSON ohne Modell")
	check(SaveCodec.parse_json("{kaputt").is_empty(), "Kaputtes JSON")
