## Holds the localized texts of several languages and looks up a text in a language, falling back to a default
## language.
##
## The texts of each language come from an l10n file, a JSON object that maps each l10n key to its text, such as
## [code]l10n.json[/code] for the fallback language and [code]l10n.fr.json[/code] for French. An l10n field of a
## generated config holds the l10n key.
## [codeblock]
## var i18n := Archmage.I18n.new("en")
## var err := i18n.merge_l10n_file("res://configs/l10n.json", "en")
## if err == OK:
##     err = i18n.merge_l10n_file("res://configs/l10n.fr.json", "fr")
## if err != OK:
##     push_error(i18n.get_error_message())
## var title := i18n.text(atlas.game_cfg.title, "fr")
## [/codeblock]
## [method merge_l10n_file_async] reads and parses the file without blocking the main thread:
## [codeblock]
## var err := await i18n.merge_l10n_file_async("res://configs/l10n.json", "en")
## [/codeblock]
## A language is identified by the string passed to the methods, such as [code]"fr"[/code]; this class does not
## interpret it.
extends RefCounted

const FileAccessFS = preload("file_access_fs.gd")
const FS = preload("fs.gd")
const I18n = preload("i18n.gd")


## Reads and parses an l10n file. [method run] may run on a worker thread, so it uses only the fields of this object.
class _L10nFileJob extends RefCounted:
	var fs: FS
	var path: String
	var err: Error = OK
	var message := ""
	## The texts to merge, or [code]null[/code] when the file is [code]null[/code].
	var texts: Variant

	func _init(p_fs: FS, p_path: String) -> void:
		fs = p_fs
		path = p_path

	func run() -> void:
		var res: Variant = fs.read_file(path)
		if res is int:
			err = res
			message = "<archmage> failed to read l10n file \"%s\": %s" % [path, error_string(res)]
			return
		var parsed: Variant = I18n._parse_l10n_data(res)
		if parsed is String:
			err = ERR_PARSE_ERROR
			message = "<archmage> failed to merge l10n file \"%s\" | %s" % [path, parsed]
			return
		texts = parsed


var _fallback: String
var _texts: Dictionary[String, Dictionary] = {}
var _error_message := ""
## Whether [method merge_l10n_file_async] uses the WorkerThreadPool. Tests set it to [code]false[/code] to run the
## path for platforms without thread support.
var _use_threads := OS.has_feature("threads")


func _init(fallback_language: String) -> void:
	_fallback = fallback_language


## Returns the fallback language.
func get_fallback() -> String:
	return _fallback


## Returns the texts of all languages: a [Dictionary] that maps each language to a [Dictionary] that maps each l10n
## key to its text. Changes to the result change later lookups.
func get_all_texts() -> Dictionary[String, Dictionary]:
	return _texts


## Adds the texts of [param texts], which maps each l10n key to its text, to the language [param lang]. A text
## replaces the earlier text of the same key.
func merge_texts(texts: Dictionary, lang: String) -> void:
	if not _texts.has(lang):
		_texts[lang] = {}
	_texts[lang].merge(texts, true)


## Parses [param data], the UTF-8 text of an l10n file, and merges its texts into the language [param lang] with
## [method merge_texts]. A [code]null[/code] text is merged as an empty string, and a [code]null[/code] file merges
## nothing. Returns [constant OK], or [constant ERR_PARSE_ERROR] when the data is not a JSON object of strings;
## [method get_error_message] then returns the message, and no text is merged.
func merge_l10n_data(data: PackedByteArray, lang: String) -> Error:
	_error_message = ""
	var msg := _merge_l10n_data(data, lang)
	if msg != "":
		_error_message = "<archmage> failed to merge l10n data | " + msg
		return ERR_PARSE_ERROR
	return OK


## Reads the l10n file at [param path] from [param fs], or with [Archmage.FileAccessFS] when [param fs] is
## [code]null[/code], and merges it as [method merge_l10n_data] does. Returns [constant OK], the error code of the
## file system when the file cannot be read, or [constant ERR_PARSE_ERROR]; [method get_error_message] then returns
## the message.
func merge_l10n_file(path: String, lang: String, fs: FS = null) -> Error:
	var job := _L10nFileJob.new(fs if fs != null else FileAccessFS.new(), path)
	job.run()
	return _finish(job, lang)


## Merges the l10n file at [param path] as [method merge_l10n_file] does, without blocking the main thread, and
## returns the same codes. Call it on the main thread with [code]await[/code].
## [br][br]
## A thread of the [WorkerThreadPool] reads and parses the file, and the main thread merges the texts. Without thread
## support, as in a Web export without threads, the file is read and parsed on the main thread.
func merge_l10n_file_async(path: String, lang: String, fs: FS = null) -> Error:
	# Why a local reference? Without it, the merge stops at its first await when the caller does not keep the I18n.
	var me := self
	var job := _L10nFileJob.new(fs if fs != null else FileAccessFS.new(), path)
	# Without a SceneTree there is no frame to await, so everything runs in this call.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not _use_threads:
		job.run()
	else:
		var task := WorkerThreadPool.add_task(job.run, false, "archmage: " + path)
		while not WorkerThreadPool.is_task_completed(task):
			await tree.process_frame
		WorkerThreadPool.wait_for_task_completion(task)
	return me._finish(job, lang)


## Returns the message of the last failed [method merge_l10n_data], [method merge_l10n_file] or
## [method merge_l10n_file_async], or an empty string when it succeeded.
func get_error_message() -> String:
	return _error_message


## Returns the text of [param key] in the language [param lang], or in the fallback language when [param lang] has
## none. Returns [code]null[/code] when neither language has the key.
func get_text(key: String, lang: String) -> Variant:
	var texts: Dictionary = _texts.get(lang, {})
	if texts.has(key):
		return texts[key]
	texts = _texts.get(_fallback, {})
	if texts.has(key):
		return texts[key]
	return null


## Returns the text of [param key] in the language [param lang], or in the fallback language when [param lang] has
## none, or [param key] itself when neither language has it. Use [method get_text] to detect a missing text.
func text(key: String, lang: String) -> String:
	var t: Variant = get_text(key, lang)
	return key if t == null else t


## Sets [member _error_message] from [param job] and, when it succeeded, merges its texts into [param lang].
## The message is set when the call returns, so that a call that overlaps another one reports its own result.
func _finish(job: _L10nFileJob, lang: String) -> Error:
	_error_message = job.message
	if job.err == OK and job.texts != null:
		merge_texts(job.texts, lang)
	return job.err


## Returns an empty string after merging the texts of [param data], or a message that describes why [param data] is
## not a JSON object of strings.
func _merge_l10n_data(data: PackedByteArray, lang: String) -> String:
	var parsed: Variant = _parse_l10n_data(data)
	if parsed is String:
		return parsed
	if parsed != null:
		merge_texts(parsed, lang)
	return ""


## Returns the texts of [param data] as a [Dictionary], [code]null[/code] when the file is [code]null[/code], or a
## message that describes why [param data] is not a JSON object of strings. It may run on a worker thread.
static func _parse_l10n_data(data: PackedByteArray) -> Variant:
	var json := JSON.new()
	if json.parse(data.get_string_from_utf8()) != OK:
		return "%s at line %d" % [json.get_error_message(), json.get_error_line() + 1]
	var d: Variant = json.data
	if d == null:
		return null
	if not d is Dictionary:
		return "expected an object"
	var texts := {}
	for k: String in d:
		var v: Variant = d[k]
		if v == null:
			texts[k] = ""
		elif v is String:
			texts[k] = v
		else:
			return "$['%s']: expected a string" % k
	return texts
