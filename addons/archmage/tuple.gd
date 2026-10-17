## A fixed number of values, the type of a tuple field.
##
## A tuple has 1 to 7 values. In the config files, it is an object with the keys [code]item0[/code] to
## [code]item6[/code].
extends RefCounted

const Tuple = preload("tuple.gd")
const ParseError = preload("parse_error.gd")

## The values, of the types of the tuple fields. A value that references a config entry holds the entry.
var items: Array = []

## [code]items[0][/code].
var item0: Variant:
	get: return items[0]
	set(value): items[0] = value
## [code]items[1][/code].
var item1: Variant:
	get: return items[1]
	set(value): items[1] = value
## [code]items[2][/code].
var item2: Variant:
	get: return items[2]
	set(value): items[2] = value
## [code]items[3][/code].
var item3: Variant:
	get: return items[3]
	set(value): items[3] = value
## [code]items[4][/code].
var item4: Variant:
	get: return items[4]
	set(value): items[4] = value
## [code]items[5][/code].
var item5: Variant:
	get: return items[5]
	set(value): items[5] = value
## [code]items[6][/code].
var item6: Variant:
	get: return items[6]
	set(value): items[6] = value

## The config IDs of the values that reference config entries, by index, for [method to_json]. The generated code
## resolves them; [method _unbind_refs] sets those values to [code]null[/code] and keeps the IDs.
var _ref_ids: Dictionary[int, Variant] = {}


## Returns the tuple in [param d], a parsed JSON object, converting the value at index [code]i[/code] with
## [code]convs[i].call(value, e)[/code], or [code]null[/code] when [param d] is [code]null[/code]. When a conversion
## records an error in [param e], returns [code]null[/code]. The values at the indexes in [param refs] are config IDs:
## they go to [member _ref_ids], and [member items] holds [code]null[/code] at those indexes until the generated code
## resolves them. Any other value that is not an object gives [code]null[/code], and the type mismatch is recorded in
## [param e] (see [method Archmage.ParseError.report_mismatch]).
static func from_json(d: Variant, convs: Array[Callable], e: ParseError = null, refs: Array[int] = []) -> Tuple:
	if d is not Dictionary:
		if d != null:
			ParseError.report_mismatch(e, "an object", d, "Archmage.Tuple")
		return null
	var t := Tuple.new()
	t.items.resize(convs.size())
	for i in convs.size():
		var v: Variant = convs[i].call(d.get("item%d" % i), e)
		if e != null and e.failed:
			return e.at(".item%d" % i)
		if i in refs:
			t._ref_ids[i] = v
		else:
			t.items[i] = v
	return t


## Returns the tuple as a JSON object. A value that references a config entry is written as its config ID.
func to_json() -> Dictionary:
	var d := {}
	for i in items.size():
		d["item%d" % i] = _ref_ids[i] if _ref_ids.has(i) else items[i]
	return d


## Returns the number of values.
func size() -> int:
	return items.size()


## Sets the values that reference config entries to [code]null[/code], so that the entries can be freed. The
## generated code calls it.
func _unbind_refs() -> void:
	for i in _ref_ids:
		items[i] = null
