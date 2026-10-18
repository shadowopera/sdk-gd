## The options of [method Archmage.AtlasLoader.load_atlas] and [method Archmage.AtlasLoader.load_atlas_async].
##
## Each [code]with_*[/code] method returns this object, so calls can be chained:
## [codeblock]
## var opts := Archmage.AtlasOptions.new() \
##         .with_blacklist(["balance"]) \
##         .with_override_root("user://override")
## [/codeblock]
## A method that gets an invalid argument records the error, and the load then fails with
## [constant ERR_INVALID_PARAMETER] and that message.
extends RefCounted

const AtlasOptions = preload("atlas_options.gd")
const AtlasLogger = preload("atlas_logger.gd")
const FileAccessFS = preload("file_access_fs.gd")
const FS = preload("fs.gd")


## An override source: a directory in the main file system, or a file system with an optional root directory.
class OverrideConfig extends RefCounted:
	## The file system of the override files; [code]null[/code] for the main file system.
	var fs: FS
	## The directory of the override files in [member fs]; empty for the root of a separate file system.
	var root: String

	func _init(p_fs: FS, p_root: String) -> void:
		fs = p_fs
		root = p_root


var _logger: AtlasLogger = AtlasLogger.new()
var _fs: FS = FileAccessFS.new()
var _atlas_modifier := Callable()
var _whitelist := PackedStringArray()
var _blacklist := PackedStringArray()
var _variants: Dictionary[String, String] = {}
var _override_configs: Array[OverrideConfig] = []
var _max_concurrency := 32
var _error := ""


## Sets the logger, which receives the progress messages. The default prints them; [Archmage.NullLogger] discards them.
func with_logger(logger: AtlasLogger) -> AtlasOptions:
	if logger == null:
		_set_error("with_logger: logger is null")
	else:
		_logger = logger
	return self


## Sets the file system that atlas.json, the config files and the files in the override roots of
## [method with_override_root] are read from. The default is [Archmage.FileAccessFS]. The override sources added with
## [method with_override_fs] use their own file systems.
func with_fs(fs: FS) -> AtlasOptions:
	if fs == null:
		_set_error("with_fs: fs is null")
	else:
		_fs = fs
	return self


## Sets a function that receives the [Archmage.AtlasJson] after atlas.json is parsed and may change it before the
## items are loaded. Its signature is [code]func(atlas_json: Archmage.AtlasJson) -> void[/code].
func with_atlas_modifier(modifier: Callable) -> AtlasOptions:
	if not modifier.is_valid():
		_set_error("with_atlas_modifier: modifier is not a valid Callable")
	else:
		_atlas_modifier = modifier
	return self


## Loads only the items whose keys are in [param keys]. When the whitelist is not empty, the blacklist is ignored.
## A key that is not an item of the atlas makes the load fail.
func with_whitelist(keys: PackedStringArray) -> AtlasOptions:
	_whitelist = keys
	return self


## Skips the items whose keys are in [param keys], unless a whitelist is set. A key that is not an item of the atlas
## makes the load fail.
func with_blacklist(keys: PackedStringArray) -> AtlasOptions:
	_blacklist = keys
	return self


## Selects the variant to load for the variant-mapped item [param key]. An item without a selected variant loads
## [code]"/"[/code]. A later call for the same key replaces the earlier one. An unknown key or an empty variant makes
## the load fail; so does a variant that atlas.json does not list for the key, unless the item is skipped.
func with_variant(key: String, variant: String) -> AtlasOptions:
	_variants[key] = variant
	return self


## Adds a directory of override files in the main file system. The override file of a config file has the same
## relative path under [param dir]: [code]<dir>/hero.json[/code] overrides [code]hero.json[/code]. After the config
## files of an item are merged, its override files are merged into the result (see
## [method Archmage.AtlasLoader.merge_json]) in the order of the config files, and for each config file in the order
## in which the sources were added, so a later source overrides an earlier one. The load fails when the directory does not exist.
func with_override_root(dir: String) -> AtlasOptions:
	if dir.strip_edges() == "":
		_set_error("with_override_root: dir is empty")
	else:
		_override_configs.append(OverrideConfig.new(null, dir))
	return self


## Adds a file system of override files, as [method with_override_root] does for a directory. The override files
## are looked up under [param root] in [param fs], or at the root of [param fs] when [param root] is empty.
func with_override_fs(fs: FS, root: String = "") -> AtlasOptions:
	if fs == null:
		_set_error("with_override_fs: fs is null")
	else:
		_override_configs.append(OverrideConfig.new(fs, root))
	return self


## Sets the maximum number of items that [method Archmage.AtlasLoader.load_atlas_async] loads at the same time. The
## default is 32. [method Archmage.AtlasLoader.load_atlas] loads one item at a time.
func with_max_concurrency(n: int) -> AtlasOptions:
	if n < 1:
		_set_error("with_max_concurrency: n must be at least 1, got %d" % n)
	else:
		_max_concurrency = n
	return self


func _set_error(message: String) -> void:
	if _error == "":
		_error = message
