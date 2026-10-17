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
## [method load_atlas_async] does the same work without blocking the main thread:
## [codeblock]
## var err := await loader.load_atlas_async("res://configs/atlas.json", "res://configs", atlas, opts)
## [/codeblock]
## The [signal progress] signal reports the items loaded so far, such as for a loading screen:
## [codeblock]
## loader.progress.connect(_on_load_progress)
##
## func _on_load_progress(loaded: int, total: int, _key: String) -> void:
##     progress_bar.max_value = total
##     progress_bar.value = loaded
## [/codeblock]
## [method cancel] stops a running load before its next item. The load then returns [constant ERR_SKIP], and the
## atlas is partly filled: do not use it.
## [br][br]
## [method load_atlas] and [method load_atlas_async] return one of these codes:
## [br]- [constant OK] on success.
## [br]- [constant ERR_INVALID_PARAMETER]: an invalid option, such as an unknown key in the whitelist, an empty
## variant, or an override root that is not a directory.
## [br]- The code of the file system, such as [constant ERR_FILE_NOT_FOUND], when a file cannot be read.
## [br]- [constant ERR_PARSE_ERROR]: a file is not valid JSON, atlas.json does not have its expected shape, or the
## [code]load_json[/code] of an item returned an error message: a value has the wrong JSON type, such as a string for
## an int field, or a value is invalid, such as a duration.
## [br]- [constant ERR_DOES_NOT_EXIST]: atlas.json has no file for an item that is loaded.
## [br]- [constant ERR_INVALID_DATA]: a reference has no entry ([method Archmage.Atlas.bind_refs] failed), or an
## item has an unknown mapping.
## [br]- [constant FAILED]: [code]AtlasExtension.on_loaded()[/code] returned an error message.
## [br]- [constant ERR_BUSY]: another loader is loading the same atlas, or this loader has not finished an earlier
## load. In the second case, [method get_error_message] keeps the message of the earlier load.
## [br]- [constant ERR_SKIP]: [method cancel] was called during the load.
extends RefCounted

## Emitted when the items to load are known, with [param loaded] 0 and an empty [param key], and after each item is
## loaded, with the number of items loaded so far and the key of that item. [param total] is the number of items to
## load, which does not include the items that the whitelist or the blacklist skips. [method load_atlas] emits it on
## the calling thread, and [method load_atlas_async] on the main thread.
signal progress(loaded: int, total: int, key: String)

const Atlas = preload("atlas.gd")
const AtlasItem = preload("atlas_item.gd")
const AtlasJson = preload("atlas_json.gd")
const AtlasLoader = preload("atlas_loader.gd")
const AtlasOptions = preload("atlas_options.gd")
const FS = preload("fs.gd")


## Reads and parses atlas.json. [method run] may run on a worker thread, so it uses only the fields of this object.
class _AtlasFileJob extends RefCounted:
	var fs: FS
	var path: String
	var err: Error = OK
	var message := ""
	var data: Variant

	func _init(p_fs: FS, p_path: String) -> void:
		fs = p_fs
		path = p_path

	func fail(p_err: Error, p_message: String) -> void:
		err = p_err
		message = p_message

	func run() -> void:
		var res: Variant = fs.read_file(path)
		if typeof(res) == TYPE_INT:
			fail(res, "<archmage> failed to read \"%s\": %s" % [path, error_string(res)])
			return
		var json := JSON.new()
		if json.parse(res.get_string_from_utf8()) != OK:
			fail(ERR_PARSE_ERROR, "<archmage> invalid \"%s\" | %s" % [path, AtlasLoader._json_error(json)])
			return
		data = json.data


## Reads, parses and merges the files of one item, then fills its object. [method run] may run on a worker thread,
## so it uses only the fields of this object and the item's object.
class _ItemJob extends RefCounted:
	var item: AtlasItem
	var cfg: Object
	var key: String
	var cfg_root: String
	var fs: FS
	var override_configs: Array[AtlasOptions.OverrideConfig]
	## The config files of the item, relative to [member cfg_root].
	var files: Array = []
	## The ID of the WorkerThreadPool task that runs [method run].
	var task_id := -1
	## The result. On failure, [member message] is the cause without the item context.
	var err: Error = OK
	var message := ""
	var paths := PackedStringArray()
	var override_count := 0
	var msec := 0

	func _init(p_item: AtlasItem, p_key: String, p_cfg_root: String, p_fs: FS,
			p_override_configs: Array[AtlasOptions.OverrideConfig]) -> void:
		item = p_item
		cfg = p_item.cfg
		key = p_key
		cfg_root = p_cfg_root
		fs = p_fs
		override_configs = p_override_configs

	func fail(p_err: Error, p_message: String) -> void:
		err = p_err
		message = p_message

	func run() -> void:
		var start := Time.get_ticks_msec()
		var merged: Variant = null
		var override_paths := PackedStringArray()
		var override_data: Array[PackedByteArray] = []
		for i in files.size():
			var f: String = files[i]
			var fp := cfg_root.path_join(f)
			var res: Variant = fs.read_file(fp)
			if typeof(res) == TYPE_INT:
				fail(res, "failed to read \"%s\": %s" % [fp, error_string(res)])
				return
			var json := JSON.new()
			if json.parse(res.get_string_from_utf8()) != OK:
				fail(ERR_PARSE_ERROR, "failed to parse \"%s\" | %s" % [fp, AtlasLoader._json_error(json)])
				return
			merged = json.data if i == 0 else AtlasLoader.merge_json(merged, json.data)
			paths.append(fp)

			for oc in override_configs:
				var ofs := oc.fs if oc.fs != null else fs
				var op := oc.root.path_join(f) if oc.root != "" else f
				if not ofs.file_exists(op):
					continue
				var ores: Variant = ofs.read_file(op)
				if typeof(ores) == TYPE_INT:
					# file_exists may return true for a missing file.
					if ores == ERR_FILE_NOT_FOUND:
						continue
					fail(ores, "failed to read override file \"%s\": %s" % [op, error_string(ores)])
					return
				override_paths.append(op)
				override_data.append(ores)

		for i in override_data.size():
			var json := JSON.new()
			if json.parse(override_data[i].get_string_from_utf8()) != OK:
				fail(ERR_PARSE_ERROR, "failed to apply override \"%s\" | %s"
						% [override_paths[i], AtlasLoader._json_error(json)])
				return
			merged = AtlasLoader.merge_json(merged, json.data)
		override_count = override_data.size()

		var msg: String = cfg.load_json(merged)
		if msg != "":
			fail(ERR_PARSE_ERROR, key + msg)
			return
		if cfg.has_method(&"apply_keys"):
			cfg.apply_keys()
		msec = Time.get_ticks_msec() - start


var _error_message := ""
## Whether a load of this loader is running.
var _busy := false
## Whether [method cancel] was called during the running load.
var _cancel_requested := false
## The number of items that the running load has loaded, and the number of items it loads, for [signal progress].
var _loaded_count := 0
var _total_count := 0
## Whether [method load_atlas_async] uses the WorkerThreadPool. Tests set it to [code]false[/code] to run the path
## for platforms without thread support.
var _use_threads := OS.has_feature("threads")


## Returns the message of the last failed load, or an empty string when it succeeded. The message starts with
## [code]<archmage>[/code] and includes context such as the item key and the file path. A message from
## [code]AtlasExtension.on_loaded()[/code] is returned unchanged.
func get_error_message() -> String:
	return _error_message


## Loads [param atlas] from [param atlas_file] on the calling thread. The file paths in atlas.json are relative to
## [param cfg_root]. Returns [constant OK] or an error code (see the class description); [method get_error_message]
## then returns the message.
func load_atlas(atlas_file: String, cfg_root: String, atlas: Atlas, options: AtlasOptions = null) -> Error:
	if _busy:
		return ERR_BUSY
	_error_message = ""
	_cancel_requested = false
	if options == null:
		options = AtlasOptions.new()
	var err := _begin(atlas, options)
	if err != OK:
		return err
	err = _load_sync(atlas_file, cfg_root, atlas, options)
	if err == OK:
		err = _on_loaded(atlas)
	_end(atlas)
	return err


## Loads [param atlas] as [method load_atlas] does, without blocking the main thread, and returns the same codes.
## Call it on the main thread with [code]await[/code].
## [br][br]
## Threads of the [WorkerThreadPool] read and parse the files of the items and call the [code]load_json[/code] and
## [code]apply_keys[/code] methods of their objects, for at most [method Archmage.AtlasOptions.with_max_concurrency]
## items at a time; the [Archmage.FS] methods that read files are called on these threads. The atlas modifier, the
## logger, [method Archmage.Atlas.bind_refs] and [method Archmage.Atlas.on_loaded] run on the main thread. Without
## thread support, as in a Web export without threads, the items are loaded on the main thread, one per frame.
## [br][br]
## Do not use [param atlas] until the load finishes, because its objects are filled over several frames. To keep
## using the loaded configs during a reload, load into a new atlas and replace the old one when the load succeeds.
func load_atlas_async(atlas_file: String, cfg_root: String, atlas: Atlas, options: AtlasOptions = null) -> Error:
	if _busy:
		return ERR_BUSY
	# Why a local reference? Without it, the load stops at its first await when the caller does not keep the loader.
	var me := self
	_error_message = ""
	_cancel_requested = false
	if options == null:
		options = AtlasOptions.new()
	var err := _begin(atlas, options)
	if err != OK:
		return err
	# Without a SceneTree there is no frame to await, so everything runs in this call.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		err = _load_sync(atlas_file, cfg_root, atlas, options)
	elif _use_threads:
		err = await _load_threaded(atlas_file, cfg_root, atlas, options, tree)
	else:
		err = await _load_main_thread(atlas_file, cfg_root, atlas, options, tree)
	if err == OK:
		err = me._on_loaded(atlas)
	me._end(atlas)
	return err


## Stops the running load before it starts its next item, or before it resolves the references when all items are
## loaded. The load then returns [constant ERR_SKIP], and [method get_error_message] returns
## [code]<archmage> load canceled[/code]. [method load_atlas_async] still waits for the items that are being loaded
## on worker threads. A canceled load does not call [method Archmage.Atlas.bind_refs] or
## [method Archmage.Atlas.on_loaded], and the atlas is partly filled: do not use it.
## [br][br]
## Call it on the thread that runs the load: during [method load_atlas_async], on the main thread, such as from a
## button; during [method load_atlas], from a handler of [signal progress]. It has no effect when no load is running.
func cancel() -> void:
	if _busy:
		_cancel_requested = true


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


## Checks the options and the atlas, and marks the start of a load.
func _begin(atlas: Atlas, opts: AtlasOptions) -> Error:
	if opts._error != "":
		return _fail(ERR_INVALID_PARAMETER, "<archmage> invalid options: " + opts._error)
	if atlas == null:
		return _fail(ERR_INVALID_PARAMETER, "<archmage> atlas is null")
	if atlas._loading:
		return _fail(ERR_BUSY, "<archmage> another loader is loading the atlas")
	var fs := opts._fs
	for oc in opts._override_configs:
		var ofs := oc.fs if oc.fs != null else fs
		if oc.fs != null and oc.root == "":
			continue
		if not ofs.dir_exists(oc.root):
			if ofs.file_exists(oc.root):
				return _fail(ERR_INVALID_PARAMETER, "<archmage> override root \"%s\" is not a directory" % oc.root)
			return _fail(ERR_INVALID_PARAMETER, "<archmage> invalid override root directory \"%s\"" % oc.root)
	_busy = true
	atlas._loading = true
	return OK


func _end(atlas: Atlas) -> void:
	_busy = false
	atlas._loading = false


func _on_loaded(atlas: Atlas) -> Error:
	var msg := atlas.on_loaded()
	if msg != "":
		return _fail(FAILED, msg)
	return OK


func _load_sync(atlas_file: String, cfg_root: String, atlas: Atlas, opts: AtlasOptions) -> Error:
	var start := Time.get_ticks_msec()
	var file_job := _AtlasFileJob.new(opts._fs, atlas_file)
	file_job.run()
	var atlas_json := _prepare(file_job, atlas, opts)
	if atlas_json == null:
		return file_job.err
	var keys := _keys_to_load(atlas, opts)
	var items := atlas.atlas_items()
	_start_progress(keys.size())
	for k in keys:
		if _cancel_requested:
			return _canceled()
		var job := _new_item_job(k, items[k], atlas_json, atlas_file, cfg_root, opts, opts._fs, opts._override_configs)
		if job.err == OK:
			job.run()
		if not _finish_item(job, atlas_file, cfg_root, opts):
			return job.err
	return _bind_refs(atlas, keys.size(), start, opts)


func _load_main_thread(atlas_file: String, cfg_root: String, atlas: Atlas, opts: AtlasOptions, tree: SceneTree) -> Error:
	var start := Time.get_ticks_msec()
	var file_job := _AtlasFileJob.new(opts._fs, atlas_file)
	file_job.run()
	var atlas_json := _prepare(file_job, atlas, opts)
	if atlas_json == null:
		return file_job.err
	var keys := _keys_to_load(atlas, opts)
	var items := atlas.atlas_items()
	_start_progress(keys.size())
	for k in keys:
		await tree.process_frame
		if _cancel_requested:
			return _canceled()
		var job := _new_item_job(k, items[k], atlas_json, atlas_file, cfg_root, opts, opts._fs, opts._override_configs)
		if job.err == OK:
			job.run()
		if not _finish_item(job, atlas_file, cfg_root, opts):
			return job.err
	return _bind_refs(atlas, keys.size(), start, opts)


func _load_threaded(atlas_file: String, cfg_root: String, atlas: Atlas, opts: AtlasOptions, tree: SceneTree) -> Error:
	var start := Time.get_ticks_msec()
	# Why copies? The worker threads read them while the caller may change the options.
	var fs := opts._fs
	var override_configs: Array[AtlasOptions.OverrideConfig] = opts._override_configs.duplicate()
	var max_concurrency := opts._max_concurrency

	var file_job := _AtlasFileJob.new(fs, atlas_file)
	var file_task := WorkerThreadPool.add_task(file_job.run, false, "archmage: " + atlas_file)
	while not WorkerThreadPool.is_task_completed(file_task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(file_task)
	var atlas_json := _prepare(file_job, atlas, opts)
	if atlas_json == null:
		return file_job.err
	var keys := _keys_to_load(atlas, opts)
	var items := atlas.atlas_items()
	_start_progress(keys.size())

	# A sliding window of at most max_concurrency tasks. After the first failure or a cancel request, no task starts,
	# and the running tasks are still waited for, because a task must not outlive the load.
	var running: Array[_ItemJob] = []
	var failed: _ItemJob = null
	var next := 0
	while true:
		while failed == null and not _cancel_requested and next < keys.size() and running.size() < max_concurrency:
			var k := keys[next]
			next += 1
			var job := _new_item_job(k, items[k], atlas_json, atlas_file, cfg_root, opts, fs, override_configs)
			if job.err != OK:
				_finish_item(job, atlas_file, cfg_root, opts)
				failed = job
				break
			job.task_id = WorkerThreadPool.add_task(job.run, false, "archmage: " + k)
			running.append(job)
		if running.is_empty():
			break
		var finished := 0
		var i := 0
		while i < running.size():
			var job := running[i]
			if not WorkerThreadPool.is_task_completed(job.task_id):
				i += 1
				continue
			WorkerThreadPool.wait_for_task_completion(job.task_id)
			running.remove_at(i)
			finished += 1
			if failed == null and not _cancel_requested:
				if not _finish_item(job, atlas_file, cfg_root, opts):
					failed = job
		if finished == 0:
			await tree.process_frame
	if failed != null:
		return failed.err
	return _bind_refs(atlas, keys.size(), start, opts)


## Checks the result of [param file_job] and the content of atlas.json, applies the atlas modifier and sets the data
## version. Returns the atlas.json, or [code]null[/code] after setting [member _error_message] and the code in
## [member _AtlasFileJob.err].
func _prepare(file_job: _AtlasFileJob, atlas: Atlas, opts: AtlasOptions) -> AtlasJson:
	if file_job.err != OK:
		_error_message = file_job.message
		return null
	var atlas_json := AtlasJson.new()
	var shape_error := atlas_json._load(file_job.data)
	if shape_error != "":
		file_job.fail(ERR_PARSE_ERROR, "<archmage> invalid \"%s\" | %s" % [file_job.path, shape_error])
		_error_message = file_job.message
		return null

	if opts._atlas_modifier.is_valid():
		opts._atlas_modifier.call(atlas_json)
	atlas.set_data_version(atlas_json.version)

	var items := atlas.atlas_items()
	var invalid := ""
	for k in opts._whitelist:
		if invalid == "" and not items.has(k):
			invalid = "<archmage> atlas whitelist: unknown item \"%s\"" % k
	for k in opts._blacklist:
		if invalid == "" and not items.has(k):
			invalid = "<archmage> atlas blacklist: unknown item \"%s\"" % k
	for k in _sorted_keys(opts._variants.keys()):
		if invalid != "":
			break
		if not items.has(k):
			invalid = "<archmage> atlas variant: unknown item \"%s\"" % k
		elif opts._variants[k] == "":
			invalid = "<archmage> atlas variant: empty variant for item \"%s\"" % k
	if invalid != "":
		file_job.fail(ERR_INVALID_PARAMETER, invalid)
		_error_message = invalid
		return null
	return atlas_json


## Returns the keys of the items to load, sorted, and logs the skipped items.
func _keys_to_load(atlas: Atlas, opts: AtlasOptions) -> Array[String]:
	var keys: Array[String] = []
	for k in _sorted_keys(atlas.atlas_items().keys()):
		var cause := _skip_cause(k, opts)
		if cause != "":
			opts._logger.info("<archmage> Skipping atlas item: %s. cause: %s" % [k, cause])
		else:
			keys.append(k)
	return keys


## Creates the job of one item and finds its files. When the files cannot be found, the job has the error. The job
## reads the files with [param fs] and [param override_configs] instead of the options, which the caller may change
## during an asynchronous load.
static func _new_item_job(key: String, item: AtlasItem, atlas_json: AtlasJson, atlas_file: String, cfg_root: String,
		opts: AtlasOptions, fs: FS, override_configs: Array[AtlasOptions.OverrideConfig]) -> _ItemJob:
	var job := _ItemJob.new(item, key, cfg_root, fs, override_configs)
	item.key = key
	var key_path := ""
	match item.mapping:
		AtlasItem.MAPPING_UNIQUE:
			if atlas_json.unique.has(key):
				job.files = [atlas_json.unique[key]]
			else:
				key_path = "$.unique['%s']" % key
		AtlasItem.MAPPING_VARIANT:
			var v: String = opts._variants.get(key, AtlasItem.DEFAULT_VARIANT)
			item.variant = v
			var f := atlas_json.pick_from_variant(key, v)
			if f != "":
				job.files = [f]
			else:
				key_path = "$.variant['%s']['%s']" % [key, v]
		AtlasItem.MAPPING_MANY:
			job.files = atlas_json.many.get(key, []).duplicate()
			if job.files.is_empty():
				key_path = "$.many['%s']" % key
		_:
			job.fail(ERR_INVALID_DATA, "unsupported mapping: %s" % item.mapping)
			return job
	if job.files.is_empty():
		job.fail(ERR_DOES_NOT_EXIST, "could not find %s in %s" % [key_path, atlas_file])
	return job


## Completes [param job] on the calling thread: logs the item and marks it ready, or sets [member _error_message] and
## returns [code]false[/code].
func _finish_item(job: _ItemJob, atlas_file: String, cfg_root: String, opts: AtlasOptions) -> bool:
	if job.err != OK:
		_error_message = "<archmage> failed to load atlas item \"%s\". atlasFile: %s, cfgRoot: %s | %s" \
				% [job.key, atlas_file, cfg_root, job.message]
		return false
	var item := job.item
	var supplement := ""
	if job.override_count == 1:
		supplement = " with 1 override"
	elif job.override_count > 1:
		supplement = " with %d overrides" % job.override_count
	var mapping := "mapping=" + item.mapping
	if item.mapping == AtlasItem.MAPPING_VARIANT:
		mapping += ", variant=" + item.variant
	opts._logger.info("<archmage> Loaded atlas item \"%s\" (%s) from %s%s in %dms"
			% [job.key, mapping, ", ".join(job.paths), supplement, job.msec])
	item.ready = true
	_loaded_count += 1
	progress.emit(_loaded_count, _total_count, job.key)
	return true


## Emits the first [signal progress] of a load that loads [param total] items.
func _start_progress(total: int) -> void:
	_loaded_count = 0
	_total_count = total
	progress.emit(0, total, "")


func _bind_refs(atlas: Atlas, count: int, start: int, opts: AtlasOptions) -> Error:
	if _cancel_requested:
		return _canceled()
	var msg := atlas.bind_refs()
	if msg != "":
		return _fail(ERR_INVALID_DATA, "<archmage> failed to bind refs | " + msg)
	opts._logger.info("<archmage> Loaded %d atlas items in %dms" % [count, Time.get_ticks_msec() - start])
	return OK


func _fail(err: Error, message: String) -> Error:
	_error_message = message
	return err


func _canceled() -> Error:
	return _fail(ERR_SKIP, "<archmage> load canceled")


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
