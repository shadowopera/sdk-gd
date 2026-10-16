## Converts parsed JSON values for the hand-written conf. A null or missing value gives the default.
extends RefCounted


static func i(v: Variant) -> int:
	return 0 if v == null else int(v)


static func f(v: Variant) -> float:
	return 0.0 if v == null else float(v)


static func s(v: Variant) -> String:
	return "" if v == null else str(v)


static func b(v: Variant) -> bool:
	return false if v == null else bool(v)
