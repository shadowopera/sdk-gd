## A 4D vector, the type of a vector field whose elements are not 32-bit, such as int64, uint16 or float64.
##
## A vector field whose elements are 32-bit, such as int32 or float32, is a [Vector4i] or [Vector4] instead.
extends RefCounted

const Vec4 = preload("vec4.gd")
const ParseError = preload("parse_error.gd")

## An [int] or a [float], as the element type of the field.
var x: Variant
## An [int] or a [float], as the element type of the field.
var y: Variant
## An [int] or a [float], as the element type of the field.
var z: Variant
## An [int] or a [float], as the element type of the field.
var w: Variant


## Returns the vector in [param d], a parsed JSON object, converting each element with
## [code]conv.call(value, e)[/code], which returns the zero value for [code]null[/code]. [code]null[/code] gives the
## zero vector. Any other value that is not an object gives the zero vector too, and the type mismatch is recorded in
## [param e] (see [method Archmage.ParseError.report_mismatch]).
static func from_json(d: Variant, conv: Callable, e: ParseError = null) -> Vec4:
	var v := Vec4.new()
	if d is not Dictionary:
		if d != null:
			ParseError.report_mismatch(e, "an object", d, "Archmage.Vec4")
		d = {}
	v.x = conv.call(d.get("x"), e)
	v.y = conv.call(d.get("y"), e)
	v.z = conv.call(d.get("z"), e)
	v.w = conv.call(d.get("w"), e)
	return v


## Returns the vector as a JSON object.
func to_json() -> Dictionary:
	return {"x": x, "y": y, "z": z, "w": w}


## Returns a [Vector4i] when the elements are integers, or a [Vector4] otherwise. A [Vector4i] keeps only the low
## 32 bits of each integer, and a [Vector4] stores 32-bit floats unless Godot is built with double precision.
func to_godot() -> Variant:
	if x is int:
		return Vector4i(x, y, z, w)
	return Vector4(x, y, z, w)
