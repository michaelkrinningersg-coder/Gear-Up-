extends TestCase


func test_big_numbers() -> void:
	check_eq(NumberFormat.big(BigNumber.zero()), "0", "Null")
	check_eq(NumberFormat.big(BigNumber.of(999.9)), "999", "Abgerundet")
	check_eq(NumberFormat.big(BigNumber.of(1234.0)), "1.234", "Tausenderpunkt")
	check_eq(NumberFormat.big(BigNumber.of(987654.0)), "987.654", "Unter einer Million ausgeschrieben")
	check_eq(NumberFormat.big(BigNumber.of(1234567.0)), "1,23 Mio.", "Millionen")
	check_eq(NumberFormat.big(BigNumber.of(25e6)), "25,0 Mio.", "Zweistellig")
	check_eq(NumberFormat.big(BigNumber.of(999.99e6)), "999 Mio.", "Nicht auf 1000 aufrunden")
	check_eq(NumberFormat.big(BigNumber.of(4.5e9)), "4,50 Mrd.", "Milliarden")
	check_eq(NumberFormat.big(BigNumber.from_log10(20.0)), "1,00e20", "Wissenschaftlich")
	check_eq(NumberFormat.big(BigNumber.of(-1500.0)), "-1.500", "Negativ")
	check_eq(NumberFormat.money(BigNumber.of(5.0)), "5 €", "Geld")


func test_small_numbers() -> void:
	check_eq(NumberFormat.num(1.15), "1,15", "Zwei Nachkommastellen")
	check_eq(NumberFormat.num(2.0), "2", "Ohne Nullen")
	check_eq(NumberFormat.num(1.26, 1), "1,3", "Eine Nachkommastelle")
	check_eq(NumberFormat.num(12345.0, 0), "12.345", "Ganzzahl mit Punkt")
	check_eq(NumberFormat.num(-0.5, 1), "-0,5", "Negativ unter eins")
	check_eq(NumberFormat.percent(0.15), "15 %", "Prozent")


func test_duration() -> void:
	check_eq(NumberFormat.duration(45.0), "45 Sek.", "Sekunden")
	check_eq(NumberFormat.duration(600.0), "10 Min.", "Minuten")
	check_eq(NumberFormat.duration(3700.0), "1 Std. 1 Min.", "Stunden")
	check_eq(NumberFormat.duration(3.0 * 86400.0 + 7200.0), "3 Tage 2 Std.", "Tage")
