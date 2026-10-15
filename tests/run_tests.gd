extends SceneTree
## Testrunner: godot --headless --path . -s res://tests/run_tests.gd
## Lädt außerdem jedes Skript unter res://scripts, damit Parse-Fehler auffallen.

const SUITES := [
	"res://tests/test_big_number.gd",
	"res://tests/test_number_format.gd",
	"res://tests/test_game_model.gd",
	"res://tests/test_save_codec.gd",
	"res://tests/test_balance.gd",
]


func _initialize() -> void:
	var failures: Array[String] = []
	var tests := 0
	var checks := 0
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null:
			failures.append("Konnte %s nicht laden" % path)
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var suite: TestCase = script.new()
			suite.test_name = "%s::%s" % [path.get_file().get_basename(), name]
			suite.call(name)
			tests += 1
			checks += suite.checks
			if suite.checks == 0:
				failures.append("%s: keine Prüfung ausgeführt (Laufzeitfehler?)" % suite.test_name)
			failures.append_array(suite.failures)
	for path in _scripts("res://scripts"):
		if load(path) == null:
			failures.append("Skript lädt nicht: %s" % path)
	for failure in failures:
		printerr("FEHLER  " + failure)
	print("%d Tests, %d Prüfungen, %d Fehler" % [tests, checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		out.append_array(_scripts(dir_path.path_join(sub)))
	return out
