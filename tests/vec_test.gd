extends "res://tests/test_case.gd"


static func to_int(v: Variant, _e: Archmage.ParseError = null) -> int:
	return 0 if v == null else int(v)


static func to_float(v: Variant, _e: Archmage.ParseError = null) -> float:
	return 0.0 if v == null else float(v)


func test_from_json_and_to_json() -> void:
	var v2 := Archmage.Vec2.from_json({"x": 1.0, "y": -2.0}, to_int)
	check_eq([v2.x, v2.y], [1, -2], "Vec2")
	check_eq(v2.to_json(), {"x": 1, "y": -2}, "Vec2.to_json")
	var v3 := Archmage.Vec3.from_json({"x": 0.1, "z": 3.0}, to_float)
	check_eq([v3.x, v3.y, v3.z], [0.1, 0.0, 3.0], "Vec3 with a missing element")
	var v4 := Archmage.Vec4.from_json(null, to_int)
	check_eq(v4.to_json(), {"x": 0, "y": 0, "z": 0, "w": 0}, "Vec4 of null")


func test_to_godot() -> void:
	check_eq(Archmage.Vec2.from_json({"x": 1, "y": 2}, to_int).to_godot(), Vector2i(1, 2), "Vec2 of int")
	check_eq(Archmage.Vec2.from_json({"x": 0.5, "y": 2}, to_float).to_godot(), Vector2(0.5, 2), "Vec2 of float")
	check_eq(Archmage.Vec3.from_json({"x": 1, "y": 2, "z": 3}, to_int).to_godot(), Vector3i(1, 2, 3), "Vec3 of int")
	check_eq(Archmage.Vec3.from_json({"x": 0.5}, to_float).to_godot(), Vector3(0.5, 0, 0), "Vec3 of float")
	check_eq(Archmage.Vec4.from_json({"w": 4}, to_int).to_godot(), Vector4i(0, 0, 0, 4), "Vec4 of int")
	check_eq(Archmage.Vec4.from_json({"w": 0.25}, to_float).to_godot(), Vector4(0, 0, 0, 0.25), "Vec4 of float")


func test_canonicalize_godot_vectors_and_colors() -> void:
	var got := Archmage.canonicalize([Vector2(0.5, -7), Vector3i(1, 2, 3), Vector4(1, 0.25, 0, -1), Color8(16, 32, 48)])
	var want := Archmage.canonicalize([{"x": 0.5, "y": -7}, {"x": 1, "y": 2, "z": 3}, {"x": 1, "y": 0.25, "z": 0, "w": -1},
			"#102030"])
	check_eq(got, want)
