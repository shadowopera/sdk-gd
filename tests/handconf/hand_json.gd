## Converts parsed JSON values for the hand-written conf, as the generated archmage.gd does. A null or missing value
## gives the default. A value of the wrong type gives the default too, and the type mismatch is recorded in [param pe].
extends RefCounted

const _NO_ARRAY: Array = []
const _NO_OBJECT: Dictionary = {}


static func i(v: Variant, pe: Archmage.ParseError = null) -> int:
	if v is float:
		return int(v)
	if v is int:
		return v
	if v != null:
		Archmage.ParseError.report_mismatch(pe, "a number", v)
	return 0


static func f(v: Variant, pe: Archmage.ParseError = null) -> float:
	if v is float:
		return v
	if v is int:
		return float(v)
	if v != null:
		Archmage.ParseError.report_mismatch(pe, "a number", v)
	return 0.0


static func s(v: Variant, pe: Archmage.ParseError = null) -> String:
	if v is String:
		return v
	if v != null:
		Archmage.ParseError.report_mismatch(pe, "a string", v)
	return ""


static func b(v: Variant, pe: Archmage.ParseError = null) -> bool:
	if v is bool:
		return v
	if v != null:
		Archmage.ParseError.report_mismatch(pe, "a boolean", v)
	return false


static func a(v: Variant, pe: Archmage.ParseError = null) -> Array:
	if v is Array:
		return v
	if v != null:
		Archmage.ParseError.report_mismatch(pe, "an array", v)
	return _NO_ARRAY


static func m(v: Variant, pe: Archmage.ParseError = null) -> Dictionary:
	if v is Dictionary:
		return v
	if v != null:
		Archmage.ParseError.report_mismatch(pe, "an object", v)
	return _NO_OBJECT


static func k(v: String, pe: Archmage.ParseError = null) -> int:
	if v.is_valid_int():
		return v.to_int()
	Archmage.ParseError.report_mismatch(pe, "an integer key", v)
	return 0


static func o(v: Variant, type_name: String, pe: Archmage.ParseError = null) -> Variant:
	if v != null:
		Archmage.ParseError.report_mismatch(pe, "an object", v, type_name)
	return null
