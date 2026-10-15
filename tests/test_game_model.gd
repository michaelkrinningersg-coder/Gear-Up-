extends TestCase


func _model() -> GameModel:
	return GameModel.new(42)


## Arbeitet einen angenommenen Auftrag mit Tipps ab und liefert die Belohnung.
func _finish_active(m: GameModel) -> Dictionary:
	for i in 10000:
		var reward := m.tap()
		if not reward.is_empty():
			return reward
	return {}


func test_new_run() -> void:
	var m := _model()
	check_eq(m.board.size(), Balance.BOARD_SIZE, "Auftragsliste gefüllt")
	check(m.money.is_zero(), "Startgeld 0")
	check_eq(m.phase, 1, "Phase 1")
	check(m.active_order.is_empty(), "Kein aktiver Auftrag")
	check(m.tap().is_empty(), "Tippen ohne Auftrag bringt nichts")


func test_complete_order() -> void:
	var m := _model()
	var expected := m.order_reward(m.board[0])
	check(m.accept_order(0), "Auftrag angenommen")
	check(not m.accept_order(1), "Nur ein Auftrag gleichzeitig")
	check_eq(m.board.size(), Balance.BOARD_SIZE, "Liste nachgefüllt")
	var reward := _finish_active(m)
	check(not reward.is_empty(), "Auftrag abgeschlossen")
	check(m.money.cmp(expected["money"]) == 0, "Geld gutgeschrieben")
	check(m.reputation.cmp(expected["rep"]) == 0, "Ruf gutgeschrieben")
	check(m.run_money.cmp(m.money) == 0, "Gesamtgeld des Runs zählt mit")
	check_eq(m.run_orders, 1, "Auftragszähler")
	check(m.active_order.is_empty(), "Wieder frei")


func test_order_kinds_trade_off() -> void:
	var m := _model()
	var quick := {"tpl": "chain_care", "tier": 0, "var": 1.0}
	var lucrative := {"tpl": "inspection", "tier": 0, "var": 1.0}
	var tricky := {"tpl": "creak", "tier": 0, "var": 1.0}
	var quick_r := m.order_reward(quick)
	var lucrative_r := m.order_reward(lucrative)
	check(quick_r["rep"].to_float() / m.order_work(quick) > lucrative_r["rep"].to_float() / m.order_work(lucrative), "Schnell: mehr Ruf pro Arbeit")
	check(lucrative_r["money"].to_float() / m.order_work(lucrative) > quick_r["money"].to_float() / m.order_work(quick), "Lukrativ: mehr Geld pro Arbeit")
	check(m.order_reward(tricky)["knowhow"].to_float() >= 1.0, "Knifflig bringt Know-how")
	check(quick_r["knowhow"].is_zero(), "Schnell bringt kein Know-how")


func test_upgrades() -> void:
	var m := _model()
	var base_cost := float(Balance.UPGRADES["toolbox"]["base_cost"])
	check_near(m.upgrade_cost("toolbox").to_float(), base_cost, 1e-9, "Grundkosten")
	check(not m.buy_upgrade("toolbox"), "Ohne Geld kein Kauf")
	m.money = BigNumber.of(1000.0)
	var before := m.tap_power()
	check(m.buy_upgrade("toolbox"), "Kauf mit Geld")
	check_eq(m.upgrade_level("toolbox"), 1, "Stufe 1")
	check_near(m.money.to_float(), 1000.0 - base_cost, 1e-9, "Kosten abgezogen")
	check(m.tap_power() > before, "Mehr Arbeit pro Tipp")
	check_near(m.upgrade_cost("toolbox").to_float(), base_cost * float(Balance.UPGRADES["toolbox"]["growth"]), 1e-9, "Kosten wachsen")


func test_upgrade_locks() -> void:
	var m := _model()
	m.money = BigNumber.of(1e9)
	check(not m.upgrade_unlocked("apprentice"), "Lehrling braucht Ruf")
	check(not m.buy_upgrade("apprentice"), "Gesperrt nicht kaufbar")
	m.reputation = BigNumber.of(float(Balance.UPGRADES["apprentice"]["requires_rep"]))
	check(m.buy_upgrade("apprentice"), "Mit Ruf kaufbar")
	var max_level := int(Balance.UPGRADES["repair_stand"]["max_level"])
	m.upgrades["repair_stand"] = max_level
	check(m.upgrade_maxed("repair_stand"), "Maximalstufe erkannt")
	check(not m.buy_upgrade("repair_stand"), "Über Maximum kein Kauf")


func test_apprentice_works() -> void:
	var m := _model()
	m.upgrades["apprentice"] = 2
	for i in 600:
		m.tick(0.1)
	check(m.run_orders > 0, "Lehrling erledigt Aufträge")
	check(m.money.to_float() > 0.0, "Lehrling verdient Geld")
	check(m.active_order.is_empty(), "Lehrling nimmt keine Aufträge von der Liste")
	check(GameModel.order_template(m.apprentice_order)["kind"] == "quick", "Lehrling macht schnelle Aufträge")


func test_offline_is_dampened() -> void:
	# Beide schon bei der besten Kundschaft, damit Ruf-Zuwachs das Verhältnis nicht verzerrt
	var top_rep := float(Balance.CUSTOMER_TIERS[-1]["rep"])
	var online := _model()
	online.upgrades["apprentice"] = 3
	online.reputation = BigNumber.of(top_rep)
	for i in 36000:
		online.tick(0.1)
	var offline := _model()
	offline.upgrades["apprentice"] = 3
	offline.reputation = BigNumber.of(top_rep)
	var report := offline.apply_offline(3600.0)
	var ratio := offline.money.to_float() / online.money.to_float()
	check(report["orders"] > 0, "Offline-Aufträge gezählt")
	check(ratio > Balance.OFFLINE_RATE * 0.75 and ratio < Balance.OFFLINE_RATE * 1.25,
		"Offline etwa %s der Online-Rate (Verhältnis %s)" % [Balance.OFFLINE_RATE, ratio])
	var idle := _model()
	check_eq(idle.apply_offline(3600.0)["orders"], 0, "Ohne Lehrling kein Offline-Fortschritt")


func test_customer_tiers() -> void:
	var m := _model()
	check_eq(m.customer_tier(), 0, "Start bei Laufkundschaft")
	var signalled := []
	m.customer_tier_changed.connect(func(tier: int) -> void: signalled.append(tier))
	var rep_needed := float(Balance.CUSTOMER_TIERS[1]["rep"])
	m.reputation = BigNumber.of(rep_needed - 1.0)
	m.accept_order(0)
	_finish_active(m)
	if m.reputation.to_float() >= rep_needed:
		check_eq(signalled, [1], "Signal bei neuer Kundschaft")
	check(m.board.any(func(o: Dictionary) -> bool: return o["tier"] == m.customer_tier()), "Neue Aufträge in aktueller Stufe")
	var small := {"tpl": "flat_tire", "tier": 0, "var": 1.0}
	var big := {"tpl": "flat_tire", "tier": 2, "var": 1.0}
	check(m.order_work(big) > m.order_work(small), "Höhere Stufe: mehr Arbeit")
	check(m.order_reward(big)["money"].gt(m.order_reward(small)["money"]), "Höhere Stufe: mehr Geld")


func test_knowhow_tree() -> void:
	var m := _model()
	check(m.branch_unlocked("workshop"), "Werkstatt-Ast ab Phase 1")
	check(not m.branch_unlocked("tech"), "Technik-Ast erst ab Phase 3")
	check(not m.buy_knowhow("routine"), "Ohne Know-how kein Kauf")
	m.knowhow = BigNumber.of(10.0)
	var before := m.tap_power()
	check(m.buy_knowhow("routine"), "Kauf mit Know-how")
	check(m.tap_power() > before, "Routine erhöht Arbeit pro Tipp")
	var chance := m.tricky_chance()
	m.knowhow = BigNumber.of(10.0)
	check(m.buy_knowhow("keen_eye"), "Spürnase kaufbar")
	check(m.tricky_chance() > chance, "Mehr knifflige Fälle")


func test_phase_goal() -> void:
	var m := _model()
	check(not m.phase_goal_met(), "Ziel anfangs offen")
	var def := m.phase_def()
	m.reputation = BigNumber.of(def["goal_rep"])
	m.money = BigNumber.of(def["goal_money"])
	check(m.phase_goal_met(), "Ziel erreicht")
	check_eq(m.can_advance_phase(), Balance.is_phase_playable(2), "Aufstieg nur, wenn Phase 2 umgesetzt ist")


func test_prestige() -> void:
	var m := _model()
	check(not m.can_prestige(), "Ohne Umsatz kein Prestige")
	m.run_money = BigNumber.of(22500.0)
	m.money = BigNumber.of(5000.0)
	m.upgrades["toolbox"] = 5
	var expected := floorf(Balance.LEGEND_K * sqrt(22500.0) + 1e-9)
	check_near(m.pending_legend().to_float(), expected, 1e-9, "Legende = k · √Gesamtgeld")
	var gained := m.prestige()
	check_near(gained.to_float(), expected, 1e-9, "Ausgezahlte Legende")
	check_near(m.legend.to_float(), expected, 1e-9, "Legende bleibt")
	check(m.money.is_zero() and m.run_money.is_zero(), "Geld zurückgesetzt")
	check_eq(m.upgrade_level("toolbox"), 0, "Ausbau zurückgesetzt")
	check_eq(m.prestige_count, 1, "Prestige gezählt")
	check_near(m.legend_mult(), 1.0 + Balance.LEGEND_BONUS_PER_POINT * expected, 1e-9, "Grundmultiplikator")
	var order := {"tpl": "chain_care", "tier": 0, "var": 1.0}
	check(m.order_reward(order)["money"].gt(GameModel.new(1).order_reward(order)["money"]), "Legende erhöht den Erlös")


func test_wipe() -> void:
	var m := _model()
	m.legend = BigNumber.of(10.0)
	m.prestige_count = 3
	m.wipe()
	check(m.legend.is_zero(), "Legende gelöscht")
	check_eq(m.prestige_count, 0, "Statistik gelöscht")


func test_serialization_roundtrip() -> void:
	var m := _model()
	m.money = BigNumber.of(1234.5)
	m.reputation = BigNumber.of(77.0)
	m.knowhow = BigNumber.of(3.0)
	m.legend = BigNumber.from_log10(30.0)
	m.upgrades = {"toolbox": 4, "apprentice": 2}
	m.knowhow_levels = {"routine": 1}
	m.accept_order(1)
	m.tap()
	m.tick(3.0)
	var json := JSON.stringify(m.to_dict(), "", false, true)
	var copy := GameModel.new(7)
	copy.from_dict(JSON.parse_string(json))
	check(copy.money.cmp(m.money) == 0, "Geld")
	check(copy.reputation.cmp(m.reputation) == 0, "Ruf")
	check(copy.legend.cmp(m.legend) == 0, "Legende")
	check_eq(copy.upgrade_level("toolbox"), 4, "Ausbaustufe")
	check_eq(typeof(copy.upgrades["toolbox"]), TYPE_INT, "Stufen als Ganzzahl")
	check_eq(copy.knowhow_level("routine"), 1, "Know-how-Stufe")
	check_eq(copy.board, m.board, "Auftragsliste")
	check_eq(copy.active_order, m.active_order, "Aktiver Auftrag")
	check_near(copy.active_progress, m.active_progress, 1e-9, "Fortschritt")
	check_eq(copy.total_taps, m.total_taps, "Tipps")


func test_load_tolerates_garbage() -> void:
	var m := _model()
	m.from_dict({"money": "kaputt", "upgrades": {"gibt_es_nicht": 3, "toolbox": -2}, "board": [{"tpl": "unbekannt"}], "phase": 99})
	check(m.money.is_zero(), "Kaputtes Geld -> 0")
	check(not m.upgrades.has("gibt_es_nicht"), "Unbekannte Upgrades verworfen")
	check_eq(m.upgrade_level("toolbox"), 0, "Negative Stufe -> 0")
	check_eq(m.board.size(), Balance.BOARD_SIZE, "Liste neu gefüllt")
	check_eq(m.phase, Balance.PHASES.size(), "Phase begrenzt")
	m.from_dict({})
	check_eq(m.phase, 1, "Leerer Stand -> Startwerte")


func _shop_model() -> GameModel:
	var m := _model()
	m.phase = 2
	m.money = BigNumber.of(10000.0)
	return m


func test_phase_one_to_two() -> void:
	var m := _model()
	var def := m.phase_def()
	m.reputation = BigNumber.of(def["goal_rep"])
	m.money = BigNumber.of(float(def["goal_money"]) + 1000.0)
	check(not m.shop_open(), "Laden in Phase 1 zu")
	check(m.advance_phase(), "Aufstieg in Phase 2")
	check_eq(m.phase, 2, "Phase 2")
	check(m.shop_open(), "Laden offen")
	check(m.stock_total() > 0, "Startbestand automatisch bestellt")
	check(m.money.lt(BigNumber.of(1000.0)), "Miete und Ware bezahlt")
	check(m.upgrade_unlocked("salesperson"), "Laden-Ausbau freigeschaltet")


func test_shop_sale() -> void:
	var m := _shop_model()
	m._restock()
	check_eq(m.stock_of("city"), m.shop_capacity(), "Nur Citybike freigeschaltet: Lager voll damit")
	check(m.sell().is_empty(), "Ohne Kundschaft kein Verkauf")
	m.shop_queue.append({"bike": "city", "wait": 10.0})
	var money_before := m.money.to_float()
	var reward := m.sell()
	check(not reward.is_empty(), "Verkauf")
	check_eq(m.run_sales, 1, "Verkauf gezählt")
	check(m.shop_queue.is_empty(), "Kundschaft bedient")
	check_eq(m.stock_of("city"), m.shop_capacity(), "Sofort nachbestellt")
	var b := Balance.bike("city")
	check_near(m.money.to_float(), money_before + float(b["sell"]) - float(b["buy"]), 1e-9, "Gewinn = Verkauf − Einkauf")
	check(m.reputation.to_float() > 0.0, "Ruf aus Verkauf")


func test_shop_customers_and_staff() -> void:
	var m := _shop_model()
	for i in 600:
		m.tick(0.1)
	check(m.shop_queue.size() + m.missed_customers > 0, "Kundschaft kommt")
	check_eq(m.run_sales, 0, "Ohne Verkäufer kein automatischer Verkauf")
	m.upgrades["salesperson"] = 5
	for i in 600:
		m.tick(0.1)
	check(m.run_sales > 0, "Verkäufer verkauft")


func test_assortment_and_unlocks() -> void:
	var m := _shop_model()
	check(not m.bike_unlocked("road"), "Rennrad braucht Ruf")
	m.reputation = BigNumber.of(10000.0)
	m.upgrades["storage"] = 2
	m._restock()
	check(m.stock_of("road") > 0, "Rennrad im Lager")
	m.set_assortment("city", false)
	check(not m.in_assortment("city"), "Ausgelistet")
	m.stock["city"] = 0
	m._restock()
	check_eq(m.stock_of("city"), 0, "Ausgelistetes wird nicht nachbestellt")
	check(m.stock_total() <= m.shop_capacity(), "Lager nie über Kapazität")
	m.shop_queue.append({"bike": "city", "wait": 1.0})
	m.tick(1.5)
	check(m.missed_customers >= 1, "Ungeduldige Kundschaft geht")


func test_shop_offline_and_save() -> void:
	var m := _shop_model()
	var report := m.apply_offline(3600.0)
	check_eq(report["sales"], 0, "Ohne Verkäufer kein Offline-Verkauf")
	m.upgrades["salesperson"] = 3
	report = m.apply_offline(3600.0)
	check(report["sales"] > 0, "Verkäufer verkauft offline")
	m._restock()
	m.shop_queue.append({"bike": "city", "wait": 5.0})
	m.set_assortment("city", false)
	var copy := GameModel.new(9)
	copy.from_dict(JSON.parse_string(JSON.stringify(m.to_dict(), "", false, true)))
	check_eq(copy.stock, m.stock, "Lager gespeichert")
	check_eq(copy.shop_queue.size(), 1, "Warteschlange gespeichert")
	check(not copy.in_assortment("city"), "Sortiment gespeichert")
	check_eq(copy.run_sales, m.run_sales, "Verkäufe gespeichert")


func test_phase_two_goal_needs_knowhow() -> void:
	var m := _shop_model()
	var def := m.phase_def()
	m.reputation = BigNumber.of(def["goal_rep"])
	m.money = BigNumber.of(def["goal_money"])
	check(not m.phase_goal_met(), "Ohne Know-how nicht erreicht")
	m.knowhow = BigNumber.of(def["goal_knowhow"])
	check(m.phase_goal_met(), "Mit Know-how erreicht")


func _brand_model() -> GameModel:
	var m := _model()
	m.phase = 3
	m.money = BigNumber.of(1e6)
	return m


func test_brand_development() -> void:
	var m := _brand_model()
	check(m.brand_open(), "Marke offen in Phase 3")
	check_eq(m.max_generation(), 1, "Ohne Rahmenmaterial nur Stahl")
	check(not m.sparte_unlocked("ebike"), "E-Bike braucht E-Antrieb")
	var cost := m.dev_cost("city")
	check(m.start_dev("city"), "Entwicklung gestartet")
	check(not m.start_dev("trekking"), "Nur ein Projekt gleichzeitig")
	check_near(m.money.to_float(), 1e6 - cost.to_float(), 1e-9, "Entwicklungskosten bezahlt")
	var knowhow_before := m.knowhow.to_float()
	for i in 100000:
		m.design_tap()
		if m.dev_project.is_empty():
			break
	check_eq(m.generation("city"), 1, "Gen 1 fertig")
	check_near(m.knowhow.to_float() - knowhow_before, Balance.DEV_KNOWHOW, 1e-9, "Know-how aus Entwicklung")
	check(not m.can_start_dev("city"), "Gen 2 braucht Alu")
	m.knowhow_levels["frame_material"] = 1
	check(m.can_start_dev("city"), "Mit Alu Gen 2 möglich")
	check(m.dev_cost("city").gt(cost), "Nächste Generation teurer")


func test_brand_economy() -> void:
	var m := _brand_model()
	check_eq(m.brand_rates()["total_units"], 0.0, "Ohne Modell keine Verkäufe")
	m.brand["city"] = {"gen": 1, "class": Balance.DEFAULT_PRICE_CLASS}
	var rates := m.brand_rates()
	check(rates["total_units"] > 0.0, "Modell verkauft sich")
	check(rates["profit"] > 0.0, "Mit Gewinn")
	check(m.market_share() > 0.0, "Marktanteil")
	m._restock()  # Laden läuft parallel und bestellt sonst im ersten Tick Ware
	var money_before := m.money.to_float()
	m.tick(10.0)
	check_near(m.money.to_float() - money_before, rates["profit"] * 10.0, 1e-6, "Gewinn pro Sekunde")
	var mid_share := m.brand_appeal_share("city")
	m.set_price_class("city", 0)
	check(m.brand_appeal_share("city") > mid_share, "Einsteiger: mehr Anteil")
	check(m.brand_price("city") < 420.0, "Einsteiger: niedrigerer Preis")
	m.set_price_class("city", 2)
	check(m.brand_appeal_share("city") < mid_share, "Premium: weniger Anteil")
	m.brand["city"]["gen"] = 2
	check(m.brand_quality("city") > 1.0, "Höhere Generation: mehr Qualität")
	m.upgrades["dealers"] = 3
	check(m.brand_reach() > Balance.BRAND_BASE_REACH, "Händlernetz erhöht Reichweite")


func test_brand_production_limit() -> void:
	var m := _brand_model()
	m.reputation = BigNumber.of(1e6)
	m.knowhow_levels = {"e_drive": 1, "frame_material": 3}
	for s in Balance.SPARTEN:
		m.brand[s["id"]] = {"gen": 4, "class": 0}
	m.upgrades["dealers"] = 8
	var rates := m.brand_rates()
	check(rates["total_units"] <= m.production_capacity() + 1e-9, "Nie mehr als die Produktion")
	m.upgrades["factory"] = 50
	check(m.brand_rates()["total_units"] > rates["total_units"], "Mehr Fertigung, mehr Absatz")


func test_brand_goal_offline_and_save() -> void:
	var m := _brand_model()
	var def := m.phase_def()
	m.money = BigNumber.of(def["goal_money"])
	check(not m.phase_goal_met(), "Ohne Marktanteil kein Aufstieg")
	m.brand["city"] = {"gen": 1, "class": 0}
	var report := m.apply_offline(3600.0)
	check(report.get("bikes", 0) > 0, "Marke verkauft offline")
	m.start_dev("trekking")
	m.design_tap()
	var copy := GameModel.new(5)
	copy.from_dict(JSON.parse_string(JSON.stringify(m.to_dict(), "", false, true)))
	check_eq(copy.generation("city"), 1, "Generation gespeichert")
	check_eq(copy.price_class("city"), 0, "Preisklasse gespeichert")
	check_eq(copy.dev_project.get("sparte"), "trekking", "Projekt gespeichert")
	check_near(float(copy.dev_project["work"]), float(m.dev_project["work"]), 1e-9, "Fortschritt gespeichert")
