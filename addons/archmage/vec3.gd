## A 3D vector, the type of a vector field whose elements are not 32-bit, such as int64, uint16 or float64.
##
## A vector field whose elements are 32-bit, such as int32 or float32, is a [Vector3i] or [Vector3] instead.
extends RefCounted

const Vec3 = preload("vec3.gd")

## An [int] or a [float], as the element type of the field.
var x: Variant
## An [int] or a [float], as the element type of the field.
var y: Variant
## An [int] or a [float], as the element type of the field.
var z: Variant


## Returns the vector in [param d], a parsed JSON object, converting each element with [param conv], which returns
## the zero value for [code]null[/code]. [code]null[/code] gives the zero vector.
static func from_json(d: Variant, conv: Callable) -> Vec3:
	var v := Vec3.new()
	if d == null:
		d = {}
	v.x = conv.call(d.get("x"))
	v.y = conv.call(d.get("y"))
	v.z = conv.call(d.get("z"))
	return v


## Returns the vector as a JSON object.
func to_json() -> Dictionary:
	return {"x": x, "y": y, "z": z}


## Returns a [Vector3i] when the elements are integers, or a [Vector3] otherwise. A [Vector3i] keeps only the low
## 32 bits of each integer, and a [Vector3] stores 32-bit floats unless Godot is built with double precision.
func to_godot() -> Variant:
	if x is int:
		return Vector3i(x, y, z)
	return Vector3(x, y, z)
