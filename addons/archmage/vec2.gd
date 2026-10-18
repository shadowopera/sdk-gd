## A 2D vector, the type of a vector field whose elements are not 32-bit, such as int64, uint16 or float64.
##
## A vector field whose elements are 32-bit, such as int32 or float32, is a [Vector2i] or [Vector2] instead.
extends RefCounted

const Vec2 = preload("vec2.gd")
const ParseError = preload("parse_error.gd")

## An [int] or a [float], as the element type of the field.
var x: Variant
## An [int] or a [float], as the element type of the field.
var y: Variant


## Returns the vector in [param d], a parsed JSON object, converting each element with
## [code]conv.call(value, e)[/code], which returns the zero value for [code]null[/code]. For [code]null[/code], returns
## the zero vector. For any other value that is not an object, returns the zero vector too and records the type
## mismatch in [param e] (see [method Archmage.ParseError.report_mismatch]).
static func from_json(d: Variant, conv: Callable, e: ParseError = null) -> Vec2:
	var v := Vec2.new()
	if d is not Dictionary:
		if d != null:
			ParseError.report_mismatch(e, "an object", d, "Archmage.Vec2")
		d = {}
	v.x = conv.call(d.get("x"), e)
	v.y = conv.call(d.get("y"), e)
	return v


## Returns the vector as a JSON object.
func to_json() -> Dictionary:
	return {"x": x, "y": y}


## Returns a [Vector2i] when the elements are integers, or a [Vector2] otherwise. A [Vector2i] keeps only the low
## 32 bits of each integer, and a [Vector2] stores 32-bit floats unless Godot is built with double precision.
func to_godot() -> Variant:
	if x is int:
		return Vector2i(x, y)
	return Vector2(x, y)
