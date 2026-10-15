extends SceneTree
## Balancing-Simulation: godot --headless --path . -s res://tools/simulate.gd
## Spielt Phase 1 mit mehreren Tipp-Raten durch und gibt Meilensteine aus.

const TAP_RATES := [0.5, 2.0, 4.0]
const SEEDS := [1, 2, 3]
const MAX_SECONDS := 3.0 * 3600.0


func _initialize() -> void:
	for tps in TAP_RATES:
		print("\n=== %s Tipps/s ===" % tps)
		var times: Array[float] = []
		for seed_value in SEEDS:
			var model := GameModel.new(seed_value)
			var bot := SimBot.new(model, tps)
			var seconds := bot.run_until_goal(MAX_SECONDS, 0.2)
			times.append(seconds)
			var parts := PackedStringArray()
			for key in bot.milestones:
				parts.append("%s %s" % [key, _minutes(bot.milestones[key])])
			print("Seed %d: Ziel %s | Gesamtgeld %s | Legende %s | Stufen %s" % [
				seed_value, _minutes(seconds), NumberFormat.money(model.run_money),
				NumberFormat.big(model.pending_legend()), str(model.upgrades)])
			print("    " + ", ".join(parts))
		times.sort()
		print("Median: %s" % _minutes(times[times.size() / 2]))
	quit()


func _minutes(seconds: float) -> String:
	if seconds < 0.0:
		return "nicht erreicht"
	return "%.1f min" % (seconds / 60.0)
