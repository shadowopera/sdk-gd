## A 2D vector, the type of a vector field whose elements are not 32-bit, such as int64, uint16 or float64.
##
## A vector field whose elements are 32-bit, such as int32 or float32, is a [Vector2i] or [Vector2] instead.
extends RefCounted

const Vec2 = preload("vec2.gd")

## An [int] or a [float], as the element type of the field.
var x: Variant
## An [int] or a [float], as the element type of the field.
var y: Variant


## Returns the vector in [param d], a parsed JSON object, converting each element with [param conv], which returns
## the zero value for [code]null[/code]. [code]null[/code] gives the zero vector.
static func from_json(d: Variant, conv: Callable) -> Vec2:
	var v := Vec2.new()
	if d == null:
		d = {}
	v.x = conv.call(d.get("x"))
	v.y = conv.call(d.get("y"))
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
