extends Node
## Rendert alle Seiten mit einem Beispiel-Spielstand als PNG.
## xvfb-run godot --path . --resolution 720x1280 res://tools/screenshot.tscn -- --out=/pfad/zum/ordner
## Achtung: überschreibt den Spielstand im Speicher (nicht auf der Platte).


func _ready() -> void:
	# Im Low-Processor-Modus wird nur bei Änderungen gezeichnet – hier immer zeichnen
	OS.low_processor_usage_mode = false
	var out_dir := OS.get_user_data_dir()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	Game.set_process(false)
	_prepare_state(Game.model)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in main.PAGES.size():
		main._show_page(i)
		await _capture(out_dir.path_join("page_%d.png" % i))
	# Werkstatt noch einmal ohne aktiven Auftrag, also mit Auftragsliste
	Game.model.active_order = {}
	main._show_page(0)
	await _capture(out_dir.path_join("page_0_board.png"))
	get_tree().quit()


func _capture(path: String) -> void:
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Gespeichert: ", path)


func _prepare_state(m: GameModel) -> void:
	m.wipe()
	m.phase = 2
	m.money = BigNumber.of(38420.0)
	m.reputation = BigNumber.of(520.0)
	m.knowhow = BigNumber.of(42.0)
	m.run_money = BigNumber.of(160000.0)
	m.run_time = 31.0 * 60.0
	m.run_orders = 412
	m.run_sales = 37
	m.upgrades = {"toolbox": 14, "apprentice": 9, "parts_shelf": 8, "repair_stand": 5,
		"salesperson": 2, "storage": 2, "sales_floor": 1}
	m.knowhow_levels = {"routine": 4, "keen_eye": 2}
	m.board.clear()
	m._fill_board()
	m._restock()
	m.shop_queue.append({"bike": "trekking", "wait": 18.0})
	m.shop_queue.append({"bike": "city", "wait": 9.0})
	m.stock["trekking"] = 0
	m.shop_queue.append({"bike": "trekking", "wait": 22.0})
	m.accept_order(0)
	for i in 3:
		m.tap()
