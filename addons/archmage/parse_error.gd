## The first invalid value and the first JSON value of the wrong type found while the generated code converts the
## parsed JSON of a config item.
##
## The generated [code]load_json[/code] creates one, so each item, and each thread, has its own. It passes it to
## every [code]from_json[/code], which records an invalid value, such as [code]"abc"[/code] for a duration, with
## [method fail] and returns early. Each caller then adds its own part of the path with [method at] or
## [method message_at], so that [code]load_json[/code] returns a message such as
## [code][3].respawn: invalid duration "abc"[/code].
## [br][br]
## A JSON value of the wrong type, such as [code]"abc"[/code] for an int field, is recorded with [method mismatch]
## instead. The conversion continues with the zero value, and [code]load_json[/code] checks [member mismatched] once
## for each config entry, so the message locates the entry, not the field:
## [code][3]: expected a number, got "abc"[/code].
extends RefCounted

const ParseError = preload("parse_error.gd")

## Whether an invalid value was found.
var failed := false
## What is wrong with the value, such as [code]invalid duration "abc"[/code].
var message := ""
## Where the value is, relative to the item, such as [code][3].respawn[/code].
var path := ""
## Whether a JSON value of the wrong type was found.
var mismatched := false
## What is wrong with the type of the first such value, such as [code]expected a number, got "abc"[/code].
var mismatch_message := ""


## Records [param msg] unless an error is already recorded.
func fail(msg: String) -> void:
	if not failed:
		failed = true
		message = msg


## Records [param msg] as a type mismatch unless one is already recorded. It does not set [member failed].
func mismatch(msg: String) -> void:
	if not mismatched:
		mismatched = true
		mismatch_message = msg


## Adds [param segment] to the front of [member path] and returns [code]null[/code], so that a
## [code]from_json[/code] can [code]return e.at(".field")[/code].
func at(segment: String) -> Variant:
	path = segment + path
	return null


## Adds [param segment] to the front of [member path] and returns the error message,
## [code]"<path>: <message>"[/code], with [member message] when [member failed] is true, or with
## [member mismatch_message] otherwise.
func message_at(segment: String) -> String:
	path = segment + path
	return path + ": " + (message if failed else mismatch_message)


## Returns [param v], a parsed JSON value, as compact JSON for an error message. Unlike [method JSON.stringify], it
## writes a [float] that is an integer without a fraction, as in the config files: [code][5,1][/code], not
## [code][5.0,1.0][/code].
static func json_text(v: Variant) -> String:
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return str(int(v))
	if v is Array:
		return "[" + ",".join(v.map(json_text)) + "]"
	if v is Dictionary:
		return "{" + ",".join(v.keys().map(func(k: Variant) -> String: return JSON.stringify(str(k)) + ":" + json_text(v[k]))) + "}"
	return JSON.stringify(v)


## Records [param msg] in [param e], or reports it with [method @GlobalScope.push_error] when [param e] is
## [code]null[/code], as when user code calls a [code]from_json[/code] directly.
static func report(e: ParseError, msg: String) -> void:
	if e == null:
		push_error("<archmage> " + msg)
	else:
		e.fail(msg)


## Records in [param e] that [param v], a parsed JSON value, is not [param expected], such as
## [code]"a number"[/code], or reports it with [method @GlobalScope.push_error] when [param e] is [code]null[/code].
## The message is [code]expected <expected>, got <v>[/code], where an array or an object is described by its kind
## and any other value by its JSON text, such as [code]expected a number, got "abc"[/code]. When
## [param type_name] is not empty, the message starts with it, such as
## [code]HeroTable.Stats: expected an object, got 5[/code].
static func report_mismatch(e: ParseError, expected: String, v: Variant, type_name := "") -> void:
	var got: String = "an array" if v is Array else "an object" if v is Dictionary else json_text(v)
	var msg := "expected %s, got %s" % [expected, got]
	if type_name != "":
		msg = type_name + ": " + msg
	if e == null:
		push_error("<archmage> " + msg)
	else:
		e.mismatch(msg)
