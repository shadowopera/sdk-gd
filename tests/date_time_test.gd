extends "res://tests/test_case.gd"

const DateTime = Archmage.DateTime


func test_round_trip() -> void:
	# [JSON, Unix time, nanosecond, offset]
	var cases := [
		["2025-01-01T00:00:00+08:00", 1735660800, 0, 28800],
		["1990-05-20T08:30:00+01:00", 643188600, 0, 3600],
		["2001-02-03T00:00:00Z", 981158400, 0, 0],
		["1969-12-31T23:59:59-00:30", 1799, 0, -1800],
		["2024-02-29T12:00:00.5Z", 1709208000, 500_000_000, 0],
		["2024-02-29T12:00:00.000000001-05:45", 1709228700, 1, -20700],
		["0001-01-02T00:00:00Z", DateTime.ZERO_UNIX_TIME + 86400, 0, 0],
		["9999-12-31T23:59:59Z", 253402300799, 0, 0],
	]
	for c: Array in cases:
		var t := DateTime.from_json(c[0])
		check_eq([t.unix_time, t.nanosecond, t.offset], [c[1], c[2], c[3]], "from_json(%s)" % c[0])
		check_eq(t.to_json(), c[0], "to_json of %s" % c[0])
		check(not t.is_zero(), "%s is not zero" % c[0])


func test_from_json_normalizes() -> void:
	check_eq(DateTime.from_json("2025-01-01T00:00:00+00:00").to_json(), "2025-01-01T00:00:00Z", "offset 0")
	check_eq(DateTime.from_json("2025-01-01T00:00:00.1200Z").to_json(), "2025-01-01T00:00:00.12Z", "fraction")
	check_eq(DateTime.from_json("2025-01-01T00:00:00.1234567891Z").nanosecond, 123456789, "more than 9 digits")


func test_zero() -> void:
	for v: Variant in [null, "0001-01-01T00:00:00Z", "0001-01-01T08:00:00+08:00"]:
		var t := DateTime.from_json(v)
		check(t.is_zero(), "from_json(%s) is zero" % v)
		check_eq(t.to_json(), null, "to_json of from_json(%s)" % v)
	check(DateTime.new().is_zero(), "new() is zero")


func test_from_json_invalid() -> void:
	for v: Variant in ["", "2025-01-01", "2025-01-01 00:00:00Z", "2025-01-01T00:00:00", "2025-13-01T00:00:00Z",
			"2023-02-29T00:00:00Z", "2025-01-01T24:00:00Z", "2025-01-01T00:00:00+24:00", 1735660800]:
		var e := Archmage.ParseError.new()
		check(DateTime.from_json(v, e).is_zero(), "from_json(%s) is zero" % v)
		check_eq(e.message, "invalid RFC 3339 time " + JSON.stringify(v), "error of from_json(%s)" % v)
