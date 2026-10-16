## Loads a generated [code]ConfigAtlas[/code] from atlas.json and the config files it lists.
##
## [codeblock]
## var atlas := ConfigAtlas.new()
## var loader := Archmage.AtlasLoader.new()
## var opts := Archmage.AtlasOptions.new().with_blacklist(["balance"])
## var err := loader.load_atlas("res://configs/atlas.json", "res://configs", atlas, opts)
## if err != OK:
##     push_error(loader.get_error_message())
## [/codeblock]
## The loader reads atlas.json, applies the atlas modifier, loads each item that is not skipped, merges the override
## files into it, calls [code]apply_keys()[/code] of the item's object when it has one, resolves the references
## between entries, and calls [method Archmage.Atlas.on_loaded]. Items are
## loaded in the order of their keys, compared without case. Create a new atlas for each load.
## [br][br]
## [method load_atlas] returns one of these codes:
## [br]- [constant OK] on success.
## [br]- [constant ERR_INVALID_PARAMETER]: an invalid option, such as an unknown key in the whitelist, an empty
## variant, or an override root that is not a directory.
## [br]- The code of the file system, such as [constant ERR_FILE_NOT_FOUND], when a file cannot be read.
## [br]- [constant ERR_PARSE_ERROR]: a file is not valid JSON, atlas.json does not have its expected shape, or the
## [code]load_json[/code] of an item returned an error message, such as for an invalid duration.
## [br]- [constant ERR_DOES_NOT_EXIST]: atlas.json has no file for an item that is loaded.
## [br]- [constant ERR_INVALID_DATA]: a reference has no entry ([method Archmage.Atlas.bind_refs] failed), or an
## item has an unknown mapping.
## [br]- [constant FAILED]: [code]AtlasExtension.on_loaded()[/code] returned an error message.
extends RefCounted

const Atlas = preload("atlas.gd")
const AtlasItem = preload("atlas_item.gd")
const AtlasJson = preload("atlas_json.gd")
const AtlasOptions = preload("atlas_options.gd")
const FS = preload("fs.gd")

var _error_message := ""


## Returns the message of the last failed [method load_atlas], or an empty string when it succeeded. The message
## starts with [code]<archmage>[/code] and includes context such as the item key and the file path. A message from
## [code]AtlasExtension.on_loaded()[/code] is returned unchanged.
func get_error_message() -> String:
	return _error_message


## Loads [param atlas] from [param atlas_file] on the calling thread. The file paths in atlas.json are relative to
## [param cfg_root]. Returns [constant OK] or an error code (see the class description); [method get_error_message]
## then returns the message.
func load_atlas(atlas_file: String, cfg_root: String, atlas: Atlas, options: AtlasOptions = null) -> Error:
	_error_message = ""
	if options == null:
		options = AtlasOptions.new()
	var err := _load_atlas(atlas_file, cfg_root, atlas, options)
	if err != OK:
		return err
	var msg := atlas.on_loaded()
	if msg != "":
		return _fail(FAILED, msg)
	return OK


## Merges [param patch] into [param target] and returns the result. This is how the files of a
## [constant Archmage.AtlasItem.MAPPING_MANY] item and the override files are combined:
## [br]- Two objects ([Dictionary]) are merged key by key: a key of [param patch] that [param target] lacks is added,
## and the values of a key in both are merged by these rules. Keys only in [param target] are kept.
## [br]- Otherwise, [param patch] replaces [param target], also when it is an array or [code]null[/code].
## [br][br]
## [code]null[/code] is a value, not a deletion: a [code]null[/code] map entry keeps its key, and the generated code
## then gives that field its default value or makes that entry [code]null[/code]. [param target] is changed in place
## when both are objects.
static func merge_json(target: Variant, patch: Variant) -> Variant:
	if not (target is Dictionary and patch is Dictionary):
		return patch
	var t: Dictionary = target
	var p: Dictionary = patch
	for k: Variant in p:
		var v: Variant = p[k]
		if v is Dictionary and t.get(k) is Dictionary:
			merge_json(t[k], v)
		else:
			t[k] = v
	return t


func _load_atlas(atlas_file: String, cfg_root: String, atlas: Atlas, opts: AtlasOptions) -> Error:
	var start := Time.get_ticks_msec()
	if opts._error != "":
		return _fail(ERR_INVALID_PARAMETER, "<archmage> invalid options: " + opts._error)
	if atlas == null:
		return _fail(ERR_INVALID_PARAMETER, "<archmage> atlas is null")

	var fs := opts._fs
	for oc in opts._override_configs:
		var ofs := oc.fs if oc.fs != null else fs
		if oc.fs != null and oc.root == "":
			continue
		if not ofs.dir_exists(oc.root):
			if ofs.file_exists(oc.root):
				return _fail(ERR_INVALID_PARAMETER, "<archmage> override root \"%s\" is not a directory" % oc.root)
			return _fail(ERR_INVALID_PARAMETER, "<archmage> invalid override root directory \"%s\"" % oc.root)

	var res: Variant = fs.read_file(atlas_file)
	if typeof(res) == TYPE_INT:
		return _fail(res, "<archmage> failed to read \"%s\": %s" % [atlas_file, error_string(res)])
	var json := JSON.new()
	if json.parse(res.get_string_from_utf8()) != OK:
		return _fail(ERR_PARSE_ERROR, "<archmage> invalid \"%s\" | %s" % [atlas_file, _json_error(json)])
	var atlas_json := AtlasJson.new()
	var shape_error := atlas_json._load(json.data)
	if shape_error != "":
		return _fail(ERR_PARSE_ERROR, "<archmage> invalid \"%s\" | %s" % [atlas_file, shape_error])

	if opts._atlas_modifier.is_valid():
		opts._atlas_modifier.call(atlas_json)
	atlas.set_data_version(atlas_json.version)

	var items := atlas.atlas_items()
	for k in opts._whitelist:
		if not items.has(k):
			return _fail(ERR_INVALID_PARAMETER, "<archmage> atlas whitelist: unknown item \"%s\"" % k)
	for k in opts._blacklist:
		if not items.has(k):
			return _fail(ERR_INVALID_PARAMETER, "<archmage> atlas blacklist: unknown item \"%s\"" % k)
	for k in _sorted_keys(opts._variants.keys()):
		if not items.has(k):
			return _fail(ERR_INVALID_PARAMETER, "<archmage> atlas variant: unknown item \"%s\"" % k)
		if opts._variants[k] == "":
			return _fail(ERR_INVALID_PARAMETER, "<archmage> atlas variant: empty variant for item \"%s\"" % k)

	var keys: Array[String] = []
	for k in _sorted_keys(items.keys()):
		var cause := _skip_cause(k, opts)
		if cause != "":
			opts._logger.info("<archmage> Skipping atlas item: %s. cause: %s" % [k, cause])
		else:
			keys.append(k)
	for k in keys:
		var err := _load_item(k, items[k], atlas_json, atlas_file, cfg_root, opts)
		if err != OK:
			_error_message = "<archmage> failed to load atlas item \"%s\". atlasFile: %s, cfgRoot: %s | %s" \
					% [k, atlas_file, cfg_root, _error_message]
			return err

	var msg := atlas.bind_refs()
	if msg != "":
		return _fail(ERR_INVALID_DATA, "<archmage> failed to bind refs | " + msg)

	opts._logger.info("<archmage> Loaded %d atlas items in %dms" % [keys.size(), Time.get_ticks_msec() - start])
	return OK


## Loads one item. On failure, sets [member _error_message] to the cause without the item context.
func _load_item(key: String, item: AtlasItem, atlas_json: AtlasJson, atlas_file: String, cfg_root: String,
		opts: AtlasOptions) -> Error:
	var start := Time.get_ticks_msec()
	item.key = key

	var files: Array = []
	var key_path := ""
	match item.mapping:
		AtlasItem.MAPPING_UNIQUE:
			if atlas_json.unique.has(key):
				files = [atlas_json.unique[key]]
			else:
				key_path = "$.unique['%s']" % key
		AtlasItem.MAPPING_VARIANT:
			var v: String = opts._variants.get(key, AtlasItem.DEFAULT_VARIANT)
			item.variant = v
			var f := atlas_json.pick_from_variant(key, v)
			if f != "":
				files = [f]
			else:
				key_path = "$.variant['%s']['%s']" % [key, v]
		AtlasItem.MAPPING_MANY:
			files = atlas_json.many.get(key, [])
			if files.is_empty():
				key_path = "$.many['%s']" % key
		_:
			return _fail(ERR_INVALID_DATA, "unsupported mapping: %s" % item.mapping)
	if files.is_empty():
		return _fail(ERR_DOES_NOT_EXIST, "could not find %s in %s" % [key_path, atlas_file])

	var fs := opts._fs
	var merged: Variant = null
	var paths := PackedStringArray()
	var override_paths := PackedStringArray()
	var override_data: Array[PackedByteArray] = []
	for i in files.size():
		var f: String = files[i]
		var fp := cfg_root.path_join(f)
		var res: Variant = fs.read_file(fp)
		if typeof(res) == TYPE_INT:
			return _fail(res, "failed to read \"%s\": %s" % [fp, error_string(res)])
		var json := JSON.new()
		if json.parse(res.get_string_from_utf8()) != OK:
			return _fail(ERR_PARSE_ERROR, "failed to parse \"%s\" | %s" % [fp, _json_error(json)])
		merged = json.data if i == 0 else merge_json(merged, json.data)
		paths.append(fp)

		for oc in opts._override_configs:
			var ofs := oc.fs if oc.fs != null else fs
			var op := oc.root.path_join(f) if oc.root != "" else f
			if not ofs.file_exists(op):
				continue
			var ores: Variant = ofs.read_file(op)
			if typeof(ores) == TYPE_INT:
				# file_exists may return true for a missing file.
				if ores == ERR_FILE_NOT_FOUND:
					continue
				return _fail(ores, "failed to read override file \"%s\": %s" % [op, error_string(ores)])
			override_paths.append(op)
			override_data.append(ores)

	for i in override_data.size():
		var json := JSON.new()
		if json.parse(override_data[i].get_string_from_utf8()) != OK:
			return _fail(ERR_PARSE_ERROR, "failed to apply override \"%s\" | %s" % [override_paths[i], _json_error(json)])
		merged = merge_json(merged, json.data)

	var msg: String = item.cfg.load_json(merged)
	if msg != "":
		return _fail(ERR_PARSE_ERROR, key + msg)
	if item.cfg.has_method(&"apply_keys"):
		item.cfg.apply_keys()

	var supplement := ""
	if override_data.size() == 1:
		supplement = " with 1 override"
	elif override_data.size() > 1:
		supplement = " with %d overrides" % override_data.size()
	var mapping := "mapping=" + item.mapping
	if item.mapping == AtlasItem.MAPPING_VARIANT:
		mapping += ", variant=" + item.variant
	opts._logger.info("<archmage> Loaded atlas item \"%s\" (%s) from %s%s in %dms"
			% [key, mapping, ", ".join(paths), supplement, Time.get_ticks_msec() - start])
	item.ready = true
	return OK


func _fail(err: Error, message: String) -> Error:
	_error_message = message
	return err


static func _skip_cause(key: String, opts: AtlasOptions) -> String:
	if not opts._whitelist.is_empty():
		return "" if opts._whitelist.has(key) else "whitelist"
	if opts._blacklist.has(key):
		return "blacklist"
	return ""


## Sorts the keys without case, as the Go and C# SDKs do; keys that differ only in case are sorted with case.
static func _sorted_keys(keys: Array) -> Array[String]:
	var sorted: Array[String] = []
	sorted.assign(keys)
	sorted.sort_custom(func(a: String, b: String) -> bool:
		var la := a.to_lower()
		var lb := b.to_lower()
		return la < lb if la != lb else a < b)
	return sorted


static func _json_error(json: JSON) -> String:
	return "%s at line %d" % [json.get_error_message(), json.get_error_line() + 1]
