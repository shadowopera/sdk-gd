## A length of time in nanoseconds, the type of a duration field.
##
## In the config files, a duration is [code]null[/code] when it is zero, [code][unit, value][/code] when it is a whole
## number of seconds (unit 0), milliseconds (1), microseconds (2), or is below one second (3), and
## [code][4, seconds, nanoseconds][/code] otherwise. For example, 1.5 seconds is [code][1, 1500][/code].
extends RefCounted

const Duration = preload("duration.gd")
const ParseError = preload("parse_error.gd")

const _UNIT_NANOSECONDS: Array[int] = [1_000_000_000, 1_000_000, 1_000, 1]

## The length in nanoseconds. It may be negative.
var nanoseconds: int


func _init(ns: int = 0) -> void:
	nanoseconds = ns


## Returns the duration in [param v], a parsed JSON value. [code]null[/code] and an empty array give a zero duration.
## For any other value that is not a valid duration, records the error in [param e] (see
## [method ParseError.report]) and returns a zero duration.
static func from_json(v: Variant, e: ParseError = null) -> Duration:
	if v == null:
		return Duration.new()
	if v is Array:
		var a: Array = v
		if a.is_empty():
			return Duration.new()
		if a.all(func(e: Variant) -> bool: return e is float or e is int):
			var unit := int(a[0])
			if a.size() == 2 and unit >= 0 and unit <= 3:
				return Duration.new(int(a[1]) * _UNIT_NANOSECONDS[unit])
			if a.size() == 3 and unit == 4:
				return Duration.new(int(a[1]) * 1_000_000_000 + int(a[2]))
	ParseError.report(e, ("invalid duration shards %s" if v is Array else "invalid duration %s") % ParseError.json_text(v))
	return Duration.new()


## Returns the duration in the format of the config files.
@warning_ignore("integer_division")
func to_json() -> Variant:
	var ns := nanoseconds
	if ns == 0:
		return null
	if ns % 1_000_000_000 == 0:
		return [0, ns / 1_000_000_000]
	if ns % 1_000_000 == 0:
		return [1, ns / 1_000_000]
	if ns % 1_000 == 0:
		return [2, ns / 1_000]
	if ns / 1_000_000_000 == 0:
		return [3, ns]
	return [4, ns / 1_000_000_000, ns % 1_000_000_000]


## Returns the duration in seconds, such as [code]1.5[/code]. Use it for Godot APIs that take seconds, such as
## [method SceneTree.create_timer].
func to_seconds() -> float:
	return nanoseconds / 1e9


## Returns the duration in whole milliseconds, truncated toward zero.
@warning_ignore("integer_division")
func to_milliseconds() -> int:
	return nanoseconds / 1_000_000
