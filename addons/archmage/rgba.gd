## Converts between [Color], the type of an rgba field, and the format of the config files.
##
## In the config files, a color is [code]"#RRGGBB"[/code] when it is opaque, [code]"#RRGGBBAA"[/code] otherwise, and
## [code]""[/code] or [code]null[/code] when every channel is 0. [Color] keeps each 8-bit channel exactly, so a color
## that is read and then written does not change.
extends RefCounted

const ParseError = preload("parse_error.gd")

const _HEX_DIGITS := "0123456789abcdefABCDEF"


## Returns the color in [param v], a parsed JSON value. [code]null[/code] and [code]""[/code] give
## [code]Color(0, 0, 0, 0)[/code]. For any other value that is not [code]"#RRGGBB"[/code] or
## [code]"#RRGGBBAA"[/code], records the error in [param e] (see [method ParseError.report]) and returns
## [code]Color(0, 0, 0, 0)[/code].
static func from_json(v: Variant, e: ParseError = null) -> Color:
	if v == null or (v is String and v == ""):
		return Color(0, 0, 0, 0)
	if v is String and v.begins_with("#") and (v.length() == 7 or v.length() == 9):
		var s: String = v
		var valid := true
		for i in range(1, s.length()):
			if not _HEX_DIGITS.contains(s[i]):
				valid = false
		if valid:
			var a := s.substr(7, 2).hex_to_int() if s.length() == 9 else 255
			return Color8(s.substr(1, 2).hex_to_int(), s.substr(3, 2).hex_to_int(), s.substr(5, 2).hex_to_int(), a)
	ParseError.report(e, ("invalid RGBA string %s" if v is String else "invalid RGBA value %s") % ParseError.json_text(v))
	return Color(0, 0, 0, 0)


## Returns [param c] in the format of the config files, with uppercase hex digits. Each channel is rounded to 8 bits.
static func to_json(c: Color) -> String:
	if c.a8 == 255:
		return "#%02X%02X%02X" % [c.r8, c.g8, c.b8]
	if c.r8 == 0 and c.g8 == 0 and c.b8 == 0 and c.a8 == 0:
		return ""
	return "#%02X%02X%02X%02X" % [c.r8, c.g8, c.b8, c.a8]
