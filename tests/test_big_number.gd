extends TestCase


func test_normalizes_on_creation() -> void:
	var n := BigNumber.of(1234.0)
	check_near(n.m, 1.234, 1e-12, "Mantisse")
	check_eq(n.e, 3, "Exponent")
	var small := BigNumber.of(0.05)
	check_near(small.m, 5.0, 1e-12, "Mantisse klein")
	check_eq(small.e, -2, "Exponent klein")
	check(BigNumber.of(0.0).is_zero(), "Null bleibt null")


func test_add_and_sub() -> void:
	check_near(BigNumber.of(950.0).add(BigNumber.of(75.0)).to_float(), 1025.0, 1e-12, "Addition")
	check_near(BigNumber.of(5.0).sub(BigNumber.of(7.5)).to_float(), -2.5, 1e-12, "Subtraktion ins Negative")
	check(BigNumber.of(42.0).sub(BigNumber.of(42.0)).is_zero(), "x - x = 0")
	var huge := BigNumber.from_log10(40.0)
	check(huge.add(BigNumber.of(1.0)).cmp(huge) == 0, "Winziger Summand ändert nichts")


func test_mul_div_pow_sqrt() -> void:
	check_near(BigNumber.of(2.5).mul(BigNumber.of(4e10)).to_float(), 1e11, 1e-12, "Multiplikation")
	check_near(BigNumber.of(1e10).div(BigNumber.of(4.0)).to_float(), 2.5e9, 1e-12, "Division")
	check_near(BigNumber.of(1.5).pow_f(10.0).to_float(), 57.6650390625, 1e-9, "Potenz")
	check_near(BigNumber.of(1e6).square_root().to_float(), 1000.0, 1e-12, "Wurzel gerader Exponent")
	check_near(BigNumber.of(1e5).square_root().to_float(), 316.227766016838, 1e-12, "Wurzel ungerader Exponent")
	check_near(BigNumber.of(0.04).square_root().to_float(), 0.2, 1e-12, "Wurzel negativer Exponent")


func test_beyond_double_range() -> void:
	var a := BigNumber.from_log10(400.0)
	check_eq(a.e, 400, "Exponent jenseits von Double")
	var b := a.mul(a)
	check_eq(b.e, 800, "Produkt")
	check_eq(b.square_root().e, 400, "Wurzel zurück")
	check(is_inf(a.to_float()), "to_float wird unendlich")
	check(BigNumber.of(1.0).lt(a), "Vergleich mit riesiger Zahl")


func test_compare() -> void:
	check(BigNumber.of(5.0).gt(BigNumber.of(3.0)), "5 > 3")
	check(BigNumber.of(-5.0).lt(BigNumber.of(3.0)), "-5 < 3")
	check(BigNumber.of(-5.0).lt(BigNumber.of(-3.0)), "-5 < -3")
	check(BigNumber.of(0.0).lt(BigNumber.of(0.001)), "0 < 0,001")
	check(BigNumber.of(1000.0).gte(BigNumber.of(1000.0)), "1000 >= 1000")
	check(BigNumber.of(999.0).lt(BigNumber.of(1000.0)), "999 < 1000")


func test_floored_and_save() -> void:
	check_near(BigNumber.of(3.7).floored().to_float(), 3.0, 1e-12, "Abrunden")
	check(BigNumber.of(0.4).floored().is_zero(), "0,4 -> 0")
	check_near(BigNumber.of(150.0).mul_f(0.02).floored().to_float(), 3.0, 1e-12, "Kein Rundungsfehler bei 3,0")
	var n := BigNumber.from_log10(123.456)
	var restored := BigNumber.from_save(JSON.parse_string(JSON.stringify(n.to_save(), "", false, true)))
	check(restored.cmp(n) == 0, "Speichern/Laden verlustfrei")
	check(BigNumber.from_save(null).is_zero(), "Fehlender Wert -> 0")
	check_near(BigNumber.from_save(12.5).to_float(), 12.5, 1e-12, "Zahl statt Array")
