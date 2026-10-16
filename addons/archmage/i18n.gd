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
## A language is identified by the string passed to the methods, such as [code]"fr"[/code]; this class does not
## interpret it.
extends RefCounted

const FileAccessFS = preload("file_access_fs.gd")
const FS = preload("fs.gd")

var _fallback: String
var _texts: Dictionary[String, Dictionary] = {}
var _error_message := ""


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
	_error_message = ""
	if fs == null:
		fs = FileAccessFS.new()
	var res: Variant = fs.read_file(path)
	if res is int:
		_error_message = "<archmage> failed to read l10n file \"%s\": %s" % [path, error_string(res)]
		return res
	var msg := _merge_l10n_data(res, lang)
	if msg != "":
		_error_message = "<archmage> failed to merge l10n file \"%s\" | %s" % [path, msg]
		return ERR_PARSE_ERROR
	return OK


## Returns the message of the last failed [method merge_l10n_data] or [method merge_l10n_file], or an empty string
## when it succeeded.
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


## Returns an empty string after merging the texts of [param data], or a message that describes why [param data] is
## not a JSON object of strings.
func _merge_l10n_data(data: PackedByteArray, lang: String) -> String:
	var json := JSON.new()
	if json.parse(data.get_string_from_utf8()) != OK:
		return "%s at line %d" % [json.get_error_message(), json.get_error_line() + 1]
	var d: Variant = json.data
	if d == null:
		return ""
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
	merge_texts(texts, lang)
	return ""
