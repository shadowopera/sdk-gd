extends "res://tests/test_case.gd"

const AtlasLoader = Archmage.AtlasLoader


func merge(target: String, patch: String) -> Variant:
	return AtlasLoader.merge_json(JSON.parse_string(target), JSON.parse_string(patch))


func test_merge_nested_object_and_array_replacement() -> void:
	var target: Variant = JSON.parse_string("{\"xxx\": \"Base\", \"foo\": {\"value\": 10, \"bar\": [1, 2, 3]}}")
	# Only the fields in the patch change.
	target = AtlasLoader.merge_json(target, JSON.parse_string("{\"foo\": {\"value\": 42}}"))
	check_eq(target, {"xxx": "Base", "foo": {"value": 42.0, "bar": [1.0, 2.0, 3.0]}}, "patch 1")
	# A nested array is replaced, not merged.
	target = AtlasLoader.merge_json(target, JSON.parse_string("{\"foo\": {\"bar\": [9, 8]}}"))
	check_eq(target, {"xxx": "Base", "foo": {"value": 42.0, "bar": [9.0, 8.0]}}, "patch 2")
	# null is a value.
	target = AtlasLoader.merge_json(target, JSON.parse_string("{\"xxx\": \"Updated\", \"foo\": null}"))
	check_eq(target, {"xxx": "Updated", "foo": null}, "patch 3")


func test_merge_top_level_array() -> void:
	check_eq(merge("[1, 2, 3]", "[4, 5]"), [4.0, 5.0])


func test_merge_object_into_non_object() -> void:
	check_eq(merge("{\"a\": null}", "{\"a\": {\"b\": 1}}"), {"a": {"b": 1.0}}, "into null")
	check_eq(merge("{\"a\": [1]}", "{\"a\": {\"b\": 1}}"), {"a": {"b": 1.0}}, "into an array")
	check_eq(merge("{\"a\": {\"b\": 1}}", "{\"a\": 2}"), {"a": 2.0}, "a scalar replaces an object")


func test_merge_map_entries() -> void:
	var got: Variant = merge("{\"m\": {\"k1\": {\"x\": 1, \"y\": 2}, \"k2\": {\"x\": 3}}}",
			"{\"m\": {\"k1\": {\"y\": 20}, \"k2\": null, \"k3\": {\"x\": 4}}}")
	check_eq(got, {"m": {"k1": {"x": 1.0, "y": 20.0}, "k2": null, "k3": {"x": 4.0}}})


func test_canonicalize_format() -> void:
	var got := Archmage.canonicalize({"b": [1, 2.5, null, {}, []], "a": {"y": true, "x": false}, "B": "s", "10": 1, "2": 2})
	var want := "{\n\t\"10\": 1,\n\t\"2\": 2,\n\t\"B\": \"s\",\n\t\"a\": {\n\t\t\"x\": false,\n\t\t\"y\": true\n\t},\n" + \
			"\t\"b\": [\n\t\t1,\n\t\t2.5,\n\t\tnull,\n\t\t{},\n\t\t[]\n\t]\n}\n"
	check_eq(got, want)


func test_canonicalize_scalars() -> void:
	check_eq(Archmage.canonicalize(null), "null\n", "null")
	check_eq(Archmage.canonicalize({}), "{}\n", "empty object")
	check_eq(Archmage.canonicalize(PackedStringArray(["a"])), "[\n\t\"a\"\n]\n", "packed array")
	check_eq(Archmage.canonicalize(&"name"), "\"name\"\n", "StringName")
	check_eq(Archmage.canonicalize({1: "a", 20: "b", 3: "c"}), "{\n\t\"1\": \"a\",\n\t\"20\": \"b\",\n\t\"3\": \"c\"\n}\n", "int keys")


func test_canonicalize_numbers() -> void:
	var cases := [
		[2.0, "2"], [-0.0, "0"], [0.25, "0.25"], [-0.015, "-0.015"], [6674.28, "6674.28"], [0.1 + 0.2, "0.30000000000000004"],
		[123456789012.0, "123456789012"], [1e300, "1e+300"], [9007199254740993, "9007199254740993"],
		[-9223372036854775807 - 1, "-9223372036854775808"],
		# The output of archmage.Canonicalize in Go.
		[1e15, "1000000000000000"], [-1e20, "-100000000000000000000"], [1e21, "1e+21"],
		[123456789012345678.0, "123456789012345680"], [9223372036854775808.0, "9223372036854776000"],
		[0.000001, "0.000001"], [0.0000001, "1e-7"], [-1.5e-7, "-1.5e-7"], [0.000123, "0.000123"],
		[-1.5e300, "-1.5e+300"],
	]
	for c: Array in cases:
		var got := Archmage.canonicalize(c[0]).trim_suffix("\n")
		check_eq(got, c[1], "canonicalize(%s)" % var_to_str(c[0]))
		# Each float must parse back to the same value.
		if typeof(c[0]) == TYPE_FLOAT:
			check_eq(JSON.parse_string(got), c[0], "round trip of %s" % got)


func test_canonicalize_strings() -> void:
	var s := "q\" b\\ n\n r\r t\t bs\b ff\f vt\v nul\u0001 é 中 /"
	var got := Archmage.canonicalize(s)
	check_eq(got, "\"q\\\" b\\\\ n\\n r\\r t\\t bs\\b ff\\f vt\\u000b nul\\u0001 é 中 /\"\n")
	check_eq(JSON.parse_string(got), s, "round trip")


class WithToJson extends RefCounted:
	var v := 1
	func to_json() -> Variant:
		return {"v": v, "inner": Inner.new()}


class Inner extends RefCounted:
	func to_json() -> Variant:
		return [true]


func test_canonicalize_objects() -> void:
	var got := Archmage.canonicalize([WithToJson.new(), null])
	check_eq(got, "[\n\t{\n\t\t\"inner\": [\n\t\t\ttrue\n\t\t],\n\t\t\"v\": 1\n\t},\n\tnull\n]\n")


func test_canonicalize_unsupported() -> void:
	capture_errors()
	var got := Archmage.canonicalize([Rect2(1, 2, 3, 4), RefCounted.new(), INF])
	var errors := take_errors()
	check_eq(got, "[\n\tnull,\n\tnull,\n\tnull\n]\n")
	check_eq(errors.size(), 3, "errors: %s" % [errors])


func test_version_info() -> void:
	var d := {"semver": "v2", "tags": ["a"], "shortId": "abc", "extra": {"k": 1}, "branch": null}
	var v := Archmage.VersionInfo.from_json(d)
	check_eq(v.semver, "v2", "semver")
	check_eq(v.tags, ["a"] as Array[String], "tags")
	check_eq(v.short_id, "abc", "short_id")
	check_eq(v.branch, "", "branch")
	check_eq(v.extra, {"k": 1}, "extra")
	check(v.timestamp.is_zero(), "a missing timestamp is zero")
	check_eq(v.to_json()["shortId"], "abc", "to_json shortId")
	check_eq(v.to_json()["timestamp"], null, "to_json of a zero timestamp")
	v = Archmage.VersionInfo.from_json({"timestamp": "2025-02-09T18:23:45.5+08:00"})
	check_eq([v.timestamp.unix_time, v.timestamp.nanosecond, v.timestamp.offset], [1739096625, 500_000_000, 28800],
			"timestamp")
	check_eq(v.to_json()["timestamp"], "2025-02-09T18:23:45.5+08:00", "to_json timestamp")
	var e := Archmage.ParseError.new()
	v = Archmage.VersionInfo.from_json({"timestamp": "now"}, e)
	check(v.timestamp.is_zero(), "an invalid timestamp is zero")
	check_eq(e.message, "invalid RFC 3339 time \"now\"", "error of an invalid timestamp")
	check(Archmage.VersionInfo.from_json(null) == null, "from_json(null)")
