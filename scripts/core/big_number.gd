class_name BigNumber
extends RefCounted
## Große Zahl als Mantisse × 10^Exponent mit 1 <= |m| < 10.
## Unveränderlich: jede Rechenoperation liefert ein neues Objekt.

const LN10 := 2.302585092994046
## Ab diesem Exponentenabstand liegt der kleinere Summand unter der Double-Genauigkeit.
const PRECISION_EXP := 17

var m: float = 0.0
var e: int = 0


func _init(mantissa: float = 0.0, exponent: int = 0) -> void:
	m = mantissa
	e = exponent
	_normalize()


static func of(value: float) -> BigNumber:
	return BigNumber.new(value, 0)


static func zero() -> BigNumber:
	return BigNumber.new(0.0, 0)


## 10^l – funktioniert auch für Exponenten jenseits des Double-Bereichs.
static func from_log10(l: float) -> BigNumber:
	var ex := floori(l)
	return BigNumber.new(pow(10.0, l - ex), ex)


static func from_save(value: Variant) -> BigNumber:
	if value is Array and value.size() == 2:
		return BigNumber.new(float(value[0]), int(value[1]))
	if value is float or value is int:
		return BigNumber.of(float(value))
	return BigNumber.zero()


func to_save() -> Array:
	return [m, e]


func _normalize() -> void:
	if is_nan(m) or is_inf(m):
		push_warning("BigNumber: ungültiger Wert %s" % m)
		m = 0.0
		e = 0
		return
	if m == 0.0:
		e = 0
		return
	var shift := floori(log(absf(m)) / LN10)
	if shift < -300:
		m = 0.0
		e = 0
		return
	if shift != 0:
		m /= pow(10.0, shift)
		e += shift
	# Rundungsfehler von log() ausgleichen
	if absf(m) >= 10.0:
		m /= 10.0
		e += 1
	elif absf(m) < 1.0:
		m *= 10.0
		e -= 1


func is_zero() -> bool:
	return m == 0.0


func is_negative() -> bool:
	return m < 0.0


func neg() -> BigNumber:
	return BigNumber.new(-m, e)


func add(o: BigNumber) -> BigNumber:
	if o.m == 0.0:
		return self
	if m == 0.0:
		return o
	var d := e - o.e
	if d > PRECISION_EXP:
		return self
	if d < -PRECISION_EXP:
		return o
	if d >= 0:
		return BigNumber.new(m + o.m / pow(10.0, d), e)
	return BigNumber.new(m / pow(10.0, -d) + o.m, o.e)


func sub(o: BigNumber) -> BigNumber:
	return add(o.neg())


func mul(o: BigNumber) -> BigNumber:
	return BigNumber.new(m * o.m, e + o.e)


func div(o: BigNumber) -> BigNumber:
	if o.m == 0.0:
		push_error("BigNumber: Division durch null")
		return BigNumber.zero()
	return BigNumber.new(m / o.m, e - o.e)


func mul_f(f: float) -> BigNumber:
	return BigNumber.new(m * f, e)


func add_f(f: float) -> BigNumber:
	return add(BigNumber.of(f))


func square_root() -> BigNumber:
	if m < 0.0:
		push_error("BigNumber: Wurzel aus negativer Zahl")
		return BigNumber.zero()
	if m == 0.0:
		return BigNumber.zero()
	if posmod(e, 2) == 1:
		return BigNumber.new(sqrt(m * 10.0), floori((e - 1) / 2.0))
	return BigNumber.new(sqrt(m), floori(e / 2.0))


## Zehnerlogarithmus (nur für positive Zahlen sinnvoll).
func log10() -> float:
	if m <= 0.0:
		return -INF
	return log(m) / LN10 + e


func pow_f(p: float) -> BigNumber:
	if m == 0.0:
		return BigNumber.zero() if p > 0.0 else BigNumber.of(1.0)
	if m < 0.0:
		push_error("BigNumber: Potenz einer negativen Zahl")
		return BigNumber.zero()
	return BigNumber.from_log10(log10() * p)


## Abrunden auf ganze Zahlen; ab 10^17 sind ohnehin keine Nachkommastellen mehr darstellbar.
func floored() -> BigNumber:
	if e >= PRECISION_EXP:
		return self
	var v := to_float()
	return BigNumber.of(floorf(v + 1e-9 * maxf(1.0, absf(v))))


func to_float() -> float:
	if e > 308:
		return INF if m > 0.0 else -INF
	if e < -308:
		return 0.0
	return m * pow(10.0, e)


func cmp(o: BigNumber) -> int:
	if m == o.m and e == o.e:
		return 0
	var sa := signf(m)
	var sb := signf(o.m)
	if sa != sb:
		return 1 if sa > sb else -1
	if e != o.e:
		var r := 1 if e > o.e else -1
		return r if sa > 0.0 else -r
	return 1 if m > o.m else -1


func gt(o: BigNumber) -> bool:
	return cmp(o) > 0


func gte(o: BigNumber) -> bool:
	return cmp(o) >= 0


func lt(o: BigNumber) -> bool:
	return cmp(o) < 0


func lte(o: BigNumber) -> bool:
	return cmp(o) <= 0


func _to_string() -> String:
	return "%se%d" % [m, e]
