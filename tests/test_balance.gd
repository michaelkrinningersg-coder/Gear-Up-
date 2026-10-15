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
