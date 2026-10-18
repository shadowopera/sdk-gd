## The entry point of the Archmage SDK and its only global class name.
##
## [codeblock]
## var atlas := ConfigAtlas.new()
## var loader := Archmage.AtlasLoader.new()
## var err := loader.load_atlas("res://configs/atlas.json", "res://configs", atlas)
## if err != OK:
##     push_error(loader.get_error_message())
## [/codeblock]
class_name Archmage
extends RefCounted

const VERSION := "0.1.0"

const Atlas = preload("atlas.gd")
const AtlasItem = preload("atlas_item.gd")
const AtlasJson = preload("atlas_json.gd")
const AtlasLoader = preload("atlas_loader.gd")
const AtlasLogger = preload("atlas_logger.gd")
const AtlasOptions = preload("atlas_options.gd")
const DateTime = preload("date_time.gd")
const Duration = preload("duration.gd")
const FileAccessFS = preload("file_access_fs.gd")
const FS = preload("fs.gd")
const I18n = preload("i18n.gd")
const MinMax = preload("min_max.gd")
const NullLogger = preload("null_logger.gd")
const ParseError = preload("parse_error.gd")
const Rgba = preload("rgba.gd")
const Tuple = preload("tuple.gd")
const Vec2 = preload("vec2.gd")
const Vec3 = preload("vec3.gd")
const Vec4 = preload("vec4.gd")
const VersionInfo = preload("version_info.gd")
const WeightedPool = preload("weighted_pool.gd")

## Matches the control characters that have no short escape in JSON.
static var _control_chars := RegEx.create_from_string("[\\x00-\\x1f]")


## Returns [param value] as canonical JSON: object keys sorted, one tab per indent level, and a trailing newline.
## [br][br]
## [param value] may contain [code]null[/code], [bool], [int], [float], [String], [StringName], [Color], Godot
## vectors, arrays, packed arrays, dictionaries, and objects that have a [code]to_json()[/code] method. For such an
## object, this method calls [code]to_json()[/code] and writes the value that [code]to_json()[/code] returns. A
## [Color] is written as the string that [code]Archmage.Rgba.to_json()[/code] returns for it, such as
## [code]"#FF8000"[/code]. A Godot vector is written as an object with one key for each component, such as
## [code]{"x": 1, "y": 2}[/code]. Dictionary keys are converted to strings with [method @GlobalScope.str]. A [float]
## is written in the format of Go's canonical JSON, such as [code]1e-7[/code]. For any other type, this method reports
## an error and writes [code]null[/code].
static func canonicalize(value: Variant) -> String:
	var out := PackedStringArray()
	_write_canonical(value, "", out)
	out.append("\n")
	return "".join(out)


## Writes each loaded item of [param atlas] to [code]<output_dir>/<key>.json[/code] with [method canonicalize].
## Items that were skipped or failed to load are not written. Returns [constant OK], or the error of the first file
## that cannot be written.
static func dump_atlas(atlas: Atlas, output_dir: String) -> Error:
	var items := atlas.atlas_items()
	var keys := items.keys()
	keys.sort()
	for key: String in keys:
		var item: AtlasItem = items[key]
		if not item.ready:
			continue
		var path := output_dir.path_join(key + ".json")
		var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if err != OK:
			push_error("<archmage> failed to dump atlas item \"%s\" | cannot create \"%s\": %s" % [key, path.get_base_dir(), error_string(err)])
			return err
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			err = FileAccess.get_open_error()
			push_error("<archmage> failed to dump atlas item \"%s\" | cannot write \"%s\": %s" % [key, path, error_string(err)])
			return err
		f.store_string(canonicalize(item.cfg))
		f.close()
	return OK


static func _write_canonical(value: Variant, indent: String, out: PackedStringArray) -> void:
	match typeof(value):
		TYPE_NIL:
			out.append("null")
		TYPE_BOOL:
			out.append("true" if value else "false")
		TYPE_INT:
			out.append(str(value))
		TYPE_FLOAT:
			out.append(_format_float(value))
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(_quote(String(value)))
		TYPE_COLOR:
			out.append(_quote(Rgba.to_json(value)))
		TYPE_VECTOR2, TYPE_VECTOR2I:
			_write_canonical({"x": value.x, "y": value.y}, indent, out)
		TYPE_VECTOR3, TYPE_VECTOR3I:
			_write_canonical({"x": value.x, "y": value.y, "z": value.z}, indent, out)
		TYPE_VECTOR4, TYPE_VECTOR4I:
			_write_canonical({"x": value.x, "y": value.y, "z": value.z, "w": value.w}, indent, out)
		TYPE_DICTIONARY:
			var d: Dictionary = value
			if d.is_empty():
				out.append("{}")
				return
			var by_name := {}
			for k: Variant in d:
				by_name[str(k)] = d[k]
			var names := by_name.keys()
			names.sort()
			var inner := indent + "\t"
			out.append("{\n")
			for i in names.size():
				if i > 0:
					out.append(",\n")
				out.append(inner)
				out.append(_quote(names[i]))
				out.append(": ")
				_write_canonical(by_name[names[i]], inner, out)
			out.append("\n")
			out.append(indent)
			out.append("}")
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			if value.is_empty():
				out.append("[]")
				return
			var inner := indent + "\t"
			out.append("[\n")
			var first := true
			for e: Variant in value:
				if not first:
					out.append(",\n")
				first = false
				out.append(inner)
				_write_canonical(e, inner, out)
			out.append("\n")
			out.append(indent)
			out.append("]")
		TYPE_OBJECT:
			if value == null:
				out.append("null")
			elif value.has_method(&"to_json"):
				_write_canonical(value.to_json(), indent, out)
			else:
				push_error("<archmage> canonicalize: %s has no to_json()" % value)
				out.append("null")
		_:
			push_error("<archmage> canonicalize: unsupported type %s" % type_string(typeof(value)))
			out.append("null")


static func _format_float(x: float) -> String:
	if is_nan(x) or is_inf(x):
		push_error("<archmage> canonicalize: %s is not a valid JSON number" % x)
		return "null"
	if x == floorf(x) and absf(x) < 1e15:
		return str(int(x))
	# num_scientific returns the shortest digits that parse back to x, such as "1e-07" or "1.2345678901234568e+17".
	# Lay them out as Go does (ECMAScript Number.prototype.toString): "1e-7", "123456789012345680".
	var t := String.num_scientific(absf(x))
	var exponent := 0
	var e := t.find("e")
	if e >= 0:
		exponent = t.substr(e + 1).to_int()
		t = t.substr(0, e)
	var dot := t.find(".")
	var digits := t.replace(".", "")
	# The value is 0.<digits> * 10^n.
	var n := (dot if dot >= 0 else t.length()) + exponent
	var lead := 0
	while digits[lead] == "0":
		lead += 1
	digits = digits.substr(lead).rstrip("0")
	n -= lead
	var k := digits.length()
	var minus := "-" if x < 0 else ""
	if k <= n and n <= 21:
		return minus + digits + "0".repeat(n - k)
	if 0 < n and n <= 21:
		return minus + digits.substr(0, n) + "." + digits.substr(n)
	if -6 < n and n <= 0:
		return minus + "0." + "0".repeat(-n) + digits
	var mantissa := digits[0] + ("." + digits.substr(1) if k > 1 else "")
	return minus + mantissa + ("e+" if n >= 1 else "e-") + str(absi(n - 1))


static func _quote(s: String) -> String:
	# Not String.json_escape(): it writes \v, which is not valid JSON.
	var escaped := s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r") \
			.replace("\t", "\\t").replace("\b", "\\b").replace("\f", "\\f")
	var m := _control_chars.search(escaped)
	if m == null:
		return "\"" + escaped + "\""
	var parts := PackedStringArray()
	var start := 0
	while m != null:
		parts.append(escaped.substr(start, m.get_start() - start))
		parts.append("\\u%04x" % escaped.unicode_at(m.get_start()))
		start = m.get_end()
		m = _control_chars.search(escaped, start)
	parts.append(escaped.substr(start))
	return "\"" + "".join(parts) + "\""
