## An inclusive range of numbers or durations, the type of a minmax field, for drawing random values.
extends RefCounted

const MinMax = preload("min_max.gd")
const Duration = preload("duration.gd")
const ParseError = preload("parse_error.gd")

## The lower bound, inclusive: an [int], a [float] or an [Archmage.Duration], as the element type of the field.
@warning_ignore("shadowed_global_identifier")
var min: Variant
## The upper bound, inclusive, of the same type as [member min].
@warning_ignore("shadowed_global_identifier")
var max: Variant


## Returns the range in [param d], a parsed JSON object, converting each bound with [code]conv.call(value, e)[/code],
## which returns the zero value for [code]null[/code]. [code]null[/code] gives a range whose bounds are zero. When
## [param conv] records an error in [param e], returns [code]null[/code]. Any other value that is not an object gives
## the same range as [code]null[/code], and the type mismatch is recorded in [param e] (see
## [method Archmage.ParseError.report_mismatch]).
static func from_json(d: Variant, conv: Callable, e: ParseError = null) -> MinMax:
	var mm := MinMax.new()
	if d is not Dictionary:
		if d != null:
			ParseError.report_mismatch(e, "an object", d, "Archmage.MinMax")
		d = {}
	mm.min = conv.call(d.get("min"), e)
	if e != null and e.failed:
		return e.at(".min")
	mm.max = conv.call(d.get("max"), e)
	if e != null and e.failed:
		return e.at(".max")
	return mm


## Returns the range as a JSON object.
func to_json() -> Dictionary:
	return {"min": min, "max": max}


@warning_ignore_start("integer_division")
## Returns a random value from [member min] to [member max], both included, drawn uniformly with [param rng], or with
## the global random number generator, which [method @GlobalScope.seed] affects, when [param rng] is
## [code]null[/code]. An [Archmage.Duration] is drawn in whole milliseconds: the bounds are truncated to milliseconds,
## and every value returned is a whole number of milliseconds.
func sample(rng: RandomNumberGenerator = null) -> Variant:
	if min is Duration:
		var lo: int = min.nanoseconds / 1_000_000
		var hi: int = max.nanoseconds / 1_000_000
		return Duration.new((lo + _rand_int(rng, hi - lo)) * 1_000_000)
	if min is int:
		return min + _rand_int(rng, max - min)
	var r := rng.randf() if rng != null else randf()
	return min + r * (max - min)
@warning_ignore_restore("integer_division")


## Returns a random integer from 0 to [param span], both included.
static func _rand_int(rng: RandomNumberGenerator, span: int) -> int:
	# randi_range takes 32-bit bounds.
	if span < 0x7FFFFFFF:
		return rng.randi_range(0, span) if rng != null else randi_range(0, span)
	# Draw 63-bit values and reject those above the largest multiple of span + 1, so that each result is equally likely.
	var n := span + 1
	var limit := 0x7FFFFFFFFFFFFFFF - (0x7FFFFFFFFFFFFFFF % n if n > 0 else 0)
	while true:
		var hi := rng.randi() if rng != null else randi()
		var lo := rng.randi() if rng != null else randi()
		var r := ((hi & 0x7FFFFFFF) << 32) | lo
		if n <= 0:
			return r
		if r < limit:
			return r % n
	return 0
