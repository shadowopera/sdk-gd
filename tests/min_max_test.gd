extends "res://tests/test_case.gd"

const MinMax = Archmage.MinMax
const Duration = Archmage.Duration


static func to_int(v: Variant, _e: Archmage.ParseError = null) -> int:
	return 0 if v == null else int(v)


static func to_float(v: Variant, _e: Archmage.ParseError = null) -> float:
	return 0.0 if v == null else float(v)


func make(lo: Variant, hi: Variant) -> MinMax:
	var mm := MinMax.new()
	mm.min = lo
	mm.max = hi
	return mm


func ms(n: int) -> Duration:
	return Duration.new(n * 1_000_000)


func test_from_json_and_to_json() -> void:
	var mm := MinMax.from_json({"min": 1.0, "max": 5.0}, to_int)
	check_eq([mm.min, mm.max], [1, 5], "int bounds")
	check_eq(mm.to_json(), {"min": 1, "max": 5}, "to_json")
	mm = MinMax.from_json(null, Duration.from_json)
	check(mm.min is Duration and mm.max is Duration, "the bounds of null are zero durations")
	check_eq(JSON.stringify(Archmage.canonicalize(mm)), JSON.stringify("{\n\t\"max\": null,\n\t\"min\": null\n}\n"),
			"canonical zero durations")
	mm = MinMax.from_json({"min": [1, 1500]}, Duration.from_json)
	check_eq([mm.min.nanoseconds, mm.max.nanoseconds], [1_500_000_000, 0], "duration bounds")
	var e := Archmage.ParseError.new()
	check(MinMax.from_json({"min": [0, 1], "max": [9, 1]}, Duration.from_json, e) == null, "an invalid bound")
	check_eq(e.message_at(""), ".max: invalid duration shards [9,1]", "error of an invalid bound")


func test_sample_int() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260827
	for bounds: Array in [[0, 0], [5, 5], [-10, 10], [1, 3], [0, 1 << 40], [-(1 << 62), 1 << 62]]:
		var mm := make(bounds[0], bounds[1])
		for i in 1000:
			var v: Variant = mm.sample(rng)
			if not (v is int and v >= bounds[0] and v <= bounds[1]):
				check(false, "sample of %s: %s" % [bounds, v])
				break
	var seen := {}
	var mm := make(1, 3)
	for i in 1000:
		seen[mm.sample(rng)] = true
	check_eq(seen.keys().size(), 3, "1, 2 and 3 are drawn")
	var big := {}
	mm = make(0, 1 << 40)
	for i in 100:
		big[mm.sample(rng) >> 31] = true
	check(big.size() > 1, "a span above 32 bits uses its high bits")


func test_sample_float() -> void:
	var mm := make(1.5, 2.5)
	for i in 1000:
		var v: Variant = mm.sample()
		if not (v is float and v >= 1.5 and v <= 2.5):
			check(false, "sample: %s" % v)
			break


func test_sample_duration() -> void:
	# From the tests of the Go SDK.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260827
	var cases := [[0, 0], [5, 5], [1, 2], [-10, 10], [3000, 120000], [0, 1_000_000_000]]
	for c: Array in cases:
		var mm := make(ms(c[0]), ms(c[1]))
		for i in 1000:
			var v: Duration = mm.sample(rng)
			if v.nanoseconds < mm.min.nanoseconds or v.nanoseconds > mm.max.nanoseconds or v.nanoseconds % 1_000_000 != 0:
				check(false, "sample of %s ms: %d ns" % [c, v.nanoseconds])
				break
	var seen := {}
	var mm := make(ms(1), ms(3))
	for i in 1000:
		seen[mm.sample(rng).nanoseconds] = true
	check_eq(seen.keys().size(), 3, "1, 2 and 3 ms are drawn")
