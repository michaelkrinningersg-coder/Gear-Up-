class_name NumberFormat
extends RefCounted
## Zahlen für die Oberfläche in deutscher Schreibweise.

## Index = Exponent / 3. Bis unter einer Million werden Zahlen ausgeschrieben.
const SUFFIXES := ["", "", " Mio.", " Mrd.", " Bio.", " Brd."]


## Ganzzahlig abgerundet bis 999.999, darüber drei gültige Stellen mit Suffix,
## jenseits der Billiarden wissenschaftlich („1,23e18").
static func big(n: BigNumber) -> String:
	if n.is_zero():
		return "0"
	var sign := "-" if n.m < 0.0 else ""
	var mantissa := absf(n.m)
	if n.e < 6:
		return sign + _group(floori(mantissa * pow(10.0, n.e) + 1e-9))
	var tier := floori(n.e / 3.0)
	if tier < SUFFIXES.size():
		var shown := mantissa * pow(10.0, n.e - tier * 3)
		return sign + _significant(shown) + SUFFIXES[tier]
	return sign + _truncated(mantissa, 2) + "e" + str(n.e)


static func money(n: BigNumber) -> String:
	return big(n) + " €"


## Kleine Kommazahl ohne überflüssige Nullen, z. B. 1,15 oder 2.
static func num(v: float, max_decimals := 2) -> String:
	if absf(v) >= 1e6:
		return big(BigNumber.of(v))
	if max_decimals <= 0:
		return _group(floori(v + 1e-9))
	var text := ("%." + str(max_decimals) + "f") % v
	if text.contains("."):
		text = text.rstrip("0").trim_suffix(".")
	var parts := text.split(".")
	var whole := _group(int(parts[0]))
	if parts[0].begins_with("-") and not whole.begins_with("-"):
		whole = "-" + whole
	if parts.size() > 1:
		return whole + "," + parts[1]
	return whole


## Prozentangabe aus einem Faktor, z. B. 0.15 -> „15 %".
static func percent(fraction: float) -> String:
	return num(fraction * 100.0, 1) + " %"


static func duration(seconds: float) -> String:
	var s := maxi(0, floori(seconds))
	if s < 60:
		return "%d Sek." % s
	var minutes := floori(s / 60.0)
	if minutes < 60:
		return "%d Min." % minutes
	var hours := floori(minutes / 60.0)
	if hours < 48:
		return "%d Std. %d Min." % [hours, minutes % 60]
	return "%d Tage %d Std." % [floori(hours / 24.0), hours % 24]


## Tausenderpunkte: 1234567 -> „1.234.567".
static func _group(v: int) -> String:
	var digits := str(absi(v))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if v < 0 else "") + out


## Drei gültige Stellen, abgeschnitten statt gerundet (999,99 bleibt unter 1000).
static func _significant(v: float) -> String:
	if v < 10.0:
		return _truncated(v, 2)
	if v < 100.0:
		return _truncated(v, 1)
	return _truncated(v, 0)


static func _truncated(v: float, decimals: int) -> String:
	var factor := pow(10.0, decimals)
	var cut := floorf(v * factor + 1e-6) / factor
	return (("%." + str(decimals) + "f") % cut).replace(".", ",")
