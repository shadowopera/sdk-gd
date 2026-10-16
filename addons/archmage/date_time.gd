## A point in time with the UTC offset it was written with, the type of a datetime field.
##
## In the config files, a datetime is an RFC 3339 string, such as [code]2025-01-01T08:30:00+08:00[/code], or
## [code]null[/code] when it is zero. The zero value is the instant [code]0001-01-01T00:00:00Z[/code], as in Go.
extends RefCounted

const DateTime = preload("date_time.gd")
const ParseError = preload("parse_error.gd")

## The Unix time of the instant at [code]0001-01-01T00:00:00Z[/code].
const ZERO_UNIX_TIME := -62135596800

static var _rfc3339: RegEx

## The seconds since [code]1970-01-01T00:00:00Z[/code], the value that [method Time.get_unix_time_from_system]
## returns.
var unix_time: int = ZERO_UNIX_TIME
## The nanoseconds within the second, from 0 to 999999999.
var nanosecond: int
## The UTC offset in seconds, such as [code]28800[/code] for [code]+08:00[/code]. [method to_json] writes the time
## with this offset.
var offset: int


## Returns whether this is the zero value. An instant is zero regardless of its offset.
func is_zero() -> bool:
	return unix_time == ZERO_UNIX_TIME and nanosecond == 0


## Returns the datetime in [param v], a parsed JSON value. [code]null[/code] gives the zero value. For any other value
## that is not an RFC 3339 string, records the error in [param e] (see [method Archmage.ParseError.report]) and
## returns the zero value.
static func from_json(v: Variant, e: ParseError = null) -> DateTime:
	var t := DateTime.new()
	if v == null:
		return t
	if _rfc3339 == null:
		_rfc3339 = RegEx.create_from_string(
				"^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})(?:\\.(\\d{1,9})\\d*)?(?:(Z)|([+-])(\\d{2}):(\\d{2}))$")
	var m: RegExMatch = _rfc3339.search(v) if v is String else null
	if m != null:
		var year := m.get_string(1).to_int()
		var month := m.get_string(2).to_int()
		var day := m.get_string(3).to_int()
		var hour := m.get_string(4).to_int()
		var minute := m.get_string(5).to_int()
		var second := m.get_string(6).to_int()
		var offset_hour := m.get_string(10).to_int()
		var offset_minute := m.get_string(11).to_int()
		if month >= 1 and month <= 12 and day >= 1 and day <= _days_in_month(year, month) and hour < 24 \
				and minute < 60 and second < 60 and offset_hour < 24 and offset_minute < 60:
			t.offset = (offset_hour * 3600 + offset_minute * 60) * (-1 if m.get_string(9) == "-" else 1)
			t.unix_time = _days_from_civil(year, month, day) * 86400 + hour * 3600 + minute * 60 + second - t.offset
			t.nanosecond = m.get_string(7).rpad(9, "0").to_int()
			return t
	ParseError.report(e, "invalid RFC 3339 time %s" % ParseError.json_text(v))
	return DateTime.new()


## Returns the datetime as an RFC 3339 string with [member offset], or [code]null[/code] for the zero value. The
## fraction of a second is written only when it is not zero, and the offset 0 is written as [code]Z[/code].
@warning_ignore("integer_division")
func to_json() -> Variant:
	if is_zero():
		return null
	var local := unix_time + offset
	var days := floori(local / 86400.0)
	var secs := local - days * 86400
	var ymd := _civil_from_days(days)
	var s := "%04d-%02d-%02dT%02d:%02d:%02d" % [ymd[0], ymd[1], ymd[2], secs / 3600, secs % 3600 / 60, secs % 60]
	if nanosecond != 0:
		s += "." + ("%09d" % nanosecond).rstrip("0")
	if offset == 0:
		return s + "Z"
	var off := absi(offset)
	return s + ("-" if offset < 0 else "+") + "%02d:%02d" % [off / 3600, off % 3600 / 60]


static func _days_in_month(year: int, month: int) -> int:
	if month == 2:
		return 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28
	return 30 if month in [4, 6, 9, 11] else 31


# The days since 1970-01-01 of a date in the proleptic Gregorian calendar (Howard Hinnant's days_from_civil).
@warning_ignore("integer_division")
static func _days_from_civil(y: int, m: int, d: int) -> int:
	if m <= 2:
		y -= 1
	var era := (y if y >= 0 else y - 399) / 400
	var yoe := y - era * 400
	var doy := (153 * (m - 3 if m > 2 else m + 9) + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


# The inverse of _days_from_civil: [year, month, day].
@warning_ignore("integer_division")
static func _civil_from_days(z: int) -> Array[int]:
	z += 719468
	var era := (z if z >= 0 else z - 146096) / 146097
	var doe := z - era * 146097
	var yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp := (5 * doy + 2) / 153
	var d := doy - (153 * mp + 2) / 5 + 1
	var m := mp + 3 if mp < 10 else mp - 9
	return [yoe + era * 400 + (1 if m <= 2 else 0), m, d]
