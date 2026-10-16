extends "res://tests/test_case.gd"

const WeightedPool = Archmage.WeightedPool


static func to_int(v: Variant, _e: Archmage.ParseError = null) -> int:
	return 0 if v == null else int(v)


## An item of the generated code that has refs.
class Item extends RefCounted:
	var unbound := false

	func _unbind_refs() -> void:
		unbound = true


func make(items: Array, weights: Array[int]) -> WeightedPool:
	var wp := WeightedPool.new()
	wp.items = items
	wp.weights = weights
	return wp


func test_from_json_and_to_json() -> void:
	check(WeightedPool.from_json(null, to_int) == null, "null")
	var wp := WeightedPool.from_json({"items": [1.0, 10.0], "weights": [90.0, 10.0]}, to_int)
	check_eq(wp.items, [1, 10], "items")
	check_eq(wp.weights, [90, 10] as Array[int], "weights")
	check_eq(wp.size(), 2, "size")
	check_eq(wp.to_json(), {"items": [1, 10], "weights": [90, 10] as Array[int]}, "to_json")
	var e := Archmage.ParseError.new()
	check(WeightedPool.from_json({"items": [[0, 1], "x"]}, Archmage.Duration.from_json, e) == null, "an invalid item")
	check_eq(e.message_at(""), ".items[1]: invalid duration \"x\"", "error of an invalid item")
	wp = WeightedPool.from_json({"items": null}, to_int)
	check_eq(wp.to_json(), {"items": [], "weights": [] as Array[int]}, "null arrays")


func test_refs() -> void:
	var wp := WeightedPool.from_json({"items": [103.0, 104.0], "weights": [5.0, 1.0]}, to_int, null, true)
	check_eq(wp.items, [null, null], "items before the refs are resolved")
	check_eq(wp.to_json()["items"], [103, 104], "to_json writes the config IDs")
	wp.items[0] = self
	wp._unbind_refs()
	check_eq(wp.items, [null, null], "items after _unbind_refs")
	check_eq(wp.to_json()["items"], [103, 104], "to_json after _unbind_refs")
	var item := Item.new()
	wp = make([item, null, 3], [1, 1, 1])
	wp._unbind_refs()
	check(item.unbound, "_unbind_refs calls _unbind_refs of the items")


func test_sample_errors() -> void:
	# [pool, error]
	var cases := [
		[make([], []), "empty pool"],
		[make([1, 2, 3], [0, 0, 0]), "total weight is zero"],
		[make([0, 1], [500_000_001, 500_000_000]), "total weight exceeds 1,000,000,000"],
	]
	for c: Array in cases:
		var wp: WeightedPool = c[0]
		capture_errors()
		var results := [wp.sample(), wp.sample_index(), wp.sample_with(0.5), wp.sample_index_with(0.5)]
		var errors := take_errors()
		check_eq(results, [null, -1, null, -1], c[1])
		check_eq(errors.size(), 4, "errors: " + c[1])
		for e in errors:
			check(e.contains(c[1]), e)


func test_sample() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var wp := make(["only"], [7])
	for i in 100:
		check_eq(wp.sample(rng), "only", "single item")
	wp = make([10, 20, 30], [5, 0, 5])
	for i in 10000:
		if wp.sample_index(rng) == 1:
			check(false, "an item with zero weight was drawn")
			break
	wp = make([0, 1, 2], [333_333_333, 333_333_333, 333_333_334])
	var seen := {}
	for i in 10000:
		seen[wp.sample_index()] = true
	check_eq(seen.size(), 3, "large equal weights")


func test_sample_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var wp := make([0, 1, 2, 3], [1, 2, 3, 4])
	var counts := [0, 0, 0, 0]
	var n := 100000
	for i in n:
		counts[wp.sample_index(rng)] += 1
	for i in 4:
		check(absf(counts[i] / float(n) - wp.weights[i] / 10.0) < 0.01, "share of item %d: %d" % [i, counts[i]])


func test_sample_with() -> void:
	# From the tests of the Go SDK.
	var wp := make(["a", "b", "c"], [1, 2, 3])
	for v in [1.0, 1.5, 100.0]:
		check_eq(wp.sample_with(v), "c", "value %s" % v)
	for v in [-0.1, -1.0, -100.0]:
		check_eq(wp.sample_with(v), "a", "value %s" % v)
	for c: Array in [[0.0, 0], [0.1666, 0], [1.0 / 6.0 * 1.5, 1], [4.0 / 6.0, 2], [5.0 / 6.0 + 0.001, 2]]:
		check_eq(wp.sample_index_with(c[0]), c[1], "value %s" % c[0])
	wp = make([10, 20, 30], [5, 0, 5])
	for i in 1001:
		if wp.sample_index_with(i / 1000.0) == 1:
			check(false, "an item with zero weight was drawn for %s" % (i / 1000.0))
			break
