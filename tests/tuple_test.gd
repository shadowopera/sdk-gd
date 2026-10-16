extends "res://tests/test_case.gd"

const Tuple = Archmage.Tuple


static func to_int(v: Variant, _e: Archmage.ParseError = null) -> int:
	return 0 if v == null else int(v)


static func to_string_value(v: Variant, _e: Archmage.ParseError = null) -> String:
	return "" if v == null else str(v)


func test_from_json_and_to_json() -> void:
	check(Tuple.from_json(null, [to_int]) == null, "null")
	var t := Tuple.from_json({"item0": 2.0, "item2": "x"}, [to_int, Archmage.Duration.from_json, to_string_value])
	check_eq(t.size(), 3, "size")
	check_eq([t.item0, t.items[1].nanoseconds, t.item2], [2, 0, "x"], "items")
	var e := Archmage.ParseError.new()
	check(Tuple.from_json({"item1": "#FFF"}, [to_int, Archmage.Rgba.from_json], e) == null, "an invalid value")
	check_eq(e.message_at(""), ".item1: invalid RGBA string \"#FFF\"", "error of an invalid value")
	t.item1 = 5
	check_eq(t.items[1], 5, "the setter of item1")
	check_eq(t.to_json(), {"item0": 2, "item1": 5, "item2": "x"}, "to_json")


func test_refs() -> void:
	var t := Tuple.from_json({"item0": 2.0, "item1": "Human"}, [to_int, to_string_value], null, [1])
	check_eq(t.items, [2, null], "items before the refs are resolved")
	check_eq(t.to_json(), {"item0": 2, "item1": "Human"}, "to_json writes the config ID")
	t.item1 = self
	t._unbind_refs()
	check_eq(t.items, [2, null], "items after _unbind_refs")
	check_eq(t.to_json(), {"item0": 2, "item1": "Human"}, "to_json after _unbind_refs")
