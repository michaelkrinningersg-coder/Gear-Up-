extends TestCase
## Grober Balancing-Wächter: ein aktiver Bot soll Phase 1 im Zielkorridor schaffen.
## Ziel laut GDD: Run 1 ca. 60 min bis Phase 3, Phase 1 also deutlich darunter.

const MIN_MINUTES := 8.0
const MAX_MINUTES := 30.0


func test_phase_one_pacing() -> void:
	var minutes: Array[float] = []
	for seed_value in [1, 2, 3]:
		var bot := SimBot.new(GameModel.new(seed_value), 4.0)
		var seconds := bot.run_until_goal(MAX_MINUTES * 60.0 * 2.0, 0.2)
		minutes.append(seconds / 60.0 if seconds > 0.0 else INF)
	for m in minutes:
		check(m >= MIN_MINUTES and m <= MAX_MINUTES,
			"Phase 1 in %s min (Korridor %s–%s min)" % [snappedf(m, 0.1), MIN_MINUTES, MAX_MINUTES])


func test_phase_two_pacing() -> void:
	# Bis zum Ziel von Phase 2 (Ende Radladen) inklusive Phase 1
	var bot := SimBot.new(GameModel.new(1), 4.0)
	var minutes := bot.run_until_phase_goal(2, 3.0 * 3600.0, 0.2) / 60.0
	check(minutes >= 25.0 and minutes <= 75.0, "Phase-2-Ziel nach %s min (Korridor 25–75 min)" % snappedf(minutes, 0.1))


func test_phase_three_pacing() -> void:
	# Erster Run bis zum Ziel von Phase 3 – laut GDD erster sinnvoller Prestige
	var bot := SimBot.new(GameModel.new(1), 4.0)
	var minutes := bot.run_until_phase_goal(3, 4.0 * 3600.0, 0.2) / 60.0
	check(minutes >= 45.0 and minutes <= 110.0, "Phase-3-Ziel nach %s min (Korridor 45–110 min)" % snappedf(minutes, 0.1))
