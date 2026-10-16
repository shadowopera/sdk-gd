extends "res://tests/test_case.gd"

const Rgba = Archmage.Rgba


func test_from_json_and_to_json() -> void:
	# [JSON, color, JSON written back], from the tests of the Go SDK.
	var cases := [
		["", Color(0, 0, 0, 0), ""],
		[null, Color(0, 0, 0, 0), ""],
		["#FF6600", Color8(0xFF, 0x66, 0x00), "#FF6600"],
		["#FF660080", Color8(0xFF, 0x66, 0x00, 0x80), "#FF660080"],
		["#aabbccdd", Color8(0xAA, 0xBB, 0xCC, 0xDD), "#AABBCCDD"],
		["#00000000", Color(0, 0, 0, 0), ""],
		["#000000", Color(0, 0, 0, 1), "#000000"],
		["#11223300", Color8(0x11, 0x22, 0x33, 0), "#11223300"],
	]
	for c: Array in cases:
		var color := Rgba.from_json(c[0])
		check_eq(color, c[1], "from_json(%s)" % c[0])
		check_eq(Rgba.to_json(color), c[2], "to_json of %s" % c[0])


func test_every_channel_value_round_trips() -> void:
	for v in 256:
		var s := "#%02X%02X%02X%02X" % [v, 255 - v, v, (v + 1) % 255]
		check_eq(Rgba.to_json(Rgba.from_json(s)), s, s)


func test_from_json_invalid() -> void:
	for v: Variant in ["FF6600", "#FF66", "#GGBBCCDD", "#FFF", "#FF6600-", 255]:
		var e := Archmage.ParseError.new()
		check_eq(Rgba.from_json(v, e), Color(0, 0, 0, 0), "from_json(%s)" % v)
		var want := ("invalid RGBA string %s" if v is String else "invalid RGBA value %s") % JSON.stringify(v)
		check_eq(e.message, want, "error of from_json(%s)" % v)
