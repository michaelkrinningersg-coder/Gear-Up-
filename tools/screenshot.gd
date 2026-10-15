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
		if i == main.BRAND_PAGE: await _capture_scrolled(main, out_dir)
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
	m.phase = 4
	m.money = BigNumber.of(3.2e6)
	m.reputation = BigNumber.of(1840.0)
	m.knowhow = BigNumber.of(37.0)
	m.run_money = BigNumber.of(2.4e6)
	m.run_time = 47.0 * 60.0
	m.run_orders = 1312
	m.run_sales = 388
	m.upgrades = {"toolbox": 24, "apprentice": 19, "parts_shelf": 15, "repair_stand": 9,
		"salesperson": 9, "storage": 8, "sales_floor": 7, "workbenches": 5, "test_track": 4, "bikefitting": 4,
		"factory": 4, "design_office": 2, "dealers": 2, "test_lab": 1}
	m.knowhow_levels = {"routine": 10, "keen_eye": 5, "master_hand": 5, "frame_material": 1, "aero": 1, "unit_cost": 1}
	m.brand = {"city": {"gen": 2, "class": 0}, "trekking": {"gen": 1, "class": 1}}
	m.dev_project = {"sparte": "mtb", "work": 1900.0}
	m.regions_open = {"north": true}
	m.campaigns.append({"region": "home", "time_left": 74.0})
	m.board.clear()
	m._fill_board()
	m._restock()
	m.shop_queue.append({"bike": "road", "wait": 18.0})
	m.shop_queue.append({"bike": "city", "wait": 9.0})


## Marke-Seite zusätzlich bis zu den Regionen gescrollt.
func _capture_scrolled(main: Control, out_dir: String) -> void:
	main._show_page(main.BRAND_PAGE)
	await _capture(out_dir.path_join("brand_top.png"))
	var page: ScrollContainer = main._pages[main.BRAND_PAGE]
	page.scroll_vertical = 700
	await _capture(out_dir.path_join("brand_regions.png"))
	page.scroll_vertical = 0
