class_name TestCase
extends RefCounted
## Minimale Testbasis: Methoden mit Präfix „test_" werden vom Runner aufgerufen.

var failures: Array[String] = []
var checks := 0
var test_name := ""


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [test_name, message])


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	check(actual == expected, "%s – erwartet %s, erhalten %s" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance := 1e-6, message := "") -> void:
	check(absf(actual - expected) <= tolerance * maxf(1.0, absf(expected)),
		"%s – erwartet ≈%s, erhalten %s" % [message, str(expected), str(actual)])
