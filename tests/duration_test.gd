extends "res://tests/test_case.gd"

const Duration = Archmage.Duration


func test_from_json_and_to_json() -> void:
	# [JSON, nanoseconds], from the tests of the Go SDK. Each JSON value is also what to_json returns.
	var cases := [
		[null, 0],
		[[0, 5], 5_000_000_000],
		[[1, 500], 500_000_000],
		[[2, 750], 750_000],
		[[3, 250], 250],
		[[4, 3, 500000001], 3_500_000_001],
		[[0, -5400], -5_400_000_000_000],
		[[4, -2, -1], -2_000_000_001],
		[[3, -999999999], -999_999_999],
	]
	for c: Array in cases:
		var json: Variant = JSON.parse_string(JSON.stringify(c[0]))
		var d := Duration.from_json(json)
		check_eq(d.nanoseconds, c[1], "from_json(%s)" % JSON.stringify(c[0]))
		check_eq(JSON.stringify(d.to_json()), JSON.stringify(c[0]), "to_json of %d" % c[1])


func test_from_json_accepts_other_shards() -> void:
	check_eq(Duration.from_json([]).nanoseconds, 0, "empty array")
	check_eq(Duration.from_json([0.0, 10.0]).nanoseconds, 10_000_000_000, "seconds")
	check_eq(Duration.from_json([4.0, 2.0, 750000001.0]).nanoseconds, 2_750_000_001, "seconds and nanoseconds")
	check_eq(JSON.stringify(Duration.new(1_500_000_000).to_json()), "[1,1500]", "1.5 seconds")
	check_eq(JSON.stringify(Duration.new(150_000_070_123).to_json()), "[4,150,70123]", "2m30.000070123s")


func test_from_json_invalid() -> void:
	for v: Variant in [[5, 100], [0, 5, 100], [4, 3, 500000000, 0], [1], ["0", 1]]:
		var e := Archmage.ParseError.new()
		check_eq(Duration.from_json(v, e).nanoseconds, 0, "from_json(%s)" % JSON.stringify(v))
		check_eq(e.message, "invalid duration shards " + JSON.stringify(v), "error of from_json(%s)" % JSON.stringify(v))
	var e := Archmage.ParseError.new()
	Duration.from_json("1s", e)
	check_eq(e.message, "invalid duration \"1s\"", "error of a string")
	# Without a ParseError, as when user code calls from_json, the error is reported with push_error.
	capture_errors()
	Duration.from_json(5)
	var errors := take_errors()
	check_eq(errors.size(), 1, "errors without a ParseError")
	if errors.size() == 1:
		check(errors[0].contains("<archmage> invalid duration 5"), errors[0])


func test_conversions() -> void:
	var d := Duration.new(1_500_999_999)
	check_eq(d.to_seconds(), 1.500999999, "to_seconds")
	check_eq(d.to_milliseconds(), 1500, "to_milliseconds")
	check_eq(Duration.new(-1_999_999).to_milliseconds(), -1, "to_milliseconds truncates toward zero")
	check_eq(Duration.new().nanoseconds, 0, "zero")
