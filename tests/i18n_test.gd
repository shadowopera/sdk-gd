extends "res://tests/test_case.gd"

const I18n = Archmage.I18n
const MemoryFS = preload("memory_fs.gd")
const ScavengerLogger = preload("scavenger_logger.gd")

const CFG_ROOT := "res://tests/testdata"


func test_merge_texts() -> void:
	var i18n := I18n.new("en")
	check_eq(i18n.get_fallback(), "en", "fallback")
	i18n.merge_texts({"hello": "Hello", "world": "World"}, "en")
	i18n.merge_texts({"hello": "Hi"}, "en")
	i18n.merge_texts({}, "fr")
	check_eq(i18n.get_all_texts(), {"en": {"hello": "Hi", "world": "World"}, "fr": {}}, "all texts")


func test_merge_l10n_data() -> void:
	# [data, error message or "" for success, texts]
	var cases := [
		["{\"hello\":\"Hello\",\"world\":\"World\"}", "", {"hello": "Hello", "world": "World"}],
		["{}", "", {}],
		["{\"hello\":\"你好\"}", "", {"hello": "你好"}],
		["{\"a\":null,\"b\":\"x\"}", "", {"a": "", "b": "x"}],
		["null", "", null],
		["{invalid json", "<archmage> failed to merge l10n data | ", null],
		["{\"hello\":1}", "<archmage> failed to merge l10n data | $['hello']: expected a string", null],
		["[]", "<archmage> failed to merge l10n data | expected an object", null],
	]
	for c: Array in cases:
		var i18n := I18n.new("en")
		var err := i18n.merge_l10n_data((c[0] as String).to_utf8_buffer(), "en")
		check_eq(err, OK if c[1] == "" else ERR_PARSE_ERROR, c[0])
		check(i18n.get_error_message().begins_with(c[1]) and (c[1] != "") == (i18n.get_error_message() != ""),
				"%s: %s" % [c[0], i18n.get_error_message()])
		check_eq(i18n.get_all_texts().get("en"), c[2], "texts of " + c[0])


func test_merge_l10n_file() -> void:
	var i18n := I18n.new("en")
	check_eq(i18n.merge_l10n_file(CFG_ROOT.path_join("l10n.json"), "en"), OK, i18n.get_error_message())
	check_eq(i18n.merge_l10n_file(CFG_ROOT.path_join("l10n.cn.json"), "zh"), OK, i18n.get_error_message())
	check_eq(i18n.text("l10n.xlsx|game.title", "zh"), "阿瓦隆传说", "translated")
	check_eq(i18n.text("game|$.tips.login", "zh"), "Welcome back!", "falls back to en")
	check_eq(i18n.get_error_message(), "", "error message after success")

	var fs := MemoryFS.new({"bad.json": "{]", "empty.json": "{}"})
	check_eq(i18n.merge_l10n_file("empty.json", "en", fs), OK, "empty file")
	check_eq(i18n.merge_l10n_file("bad.json", "en", fs), ERR_PARSE_ERROR, "bad file")
	check(i18n.get_error_message().begins_with("<archmage> failed to merge l10n file \"bad.json\" | "),
			i18n.get_error_message())
	check_eq(i18n.merge_l10n_file("missing.json", "en", fs), ERR_FILE_NOT_FOUND, "missing file")
	check_eq(i18n.get_error_message(), "<archmage> failed to read l10n file \"missing.json\": File not found",
			"missing file message")


func test_merge_l10n_file_async() -> void:
	for threaded: bool in [true, false]:
		var i18n := I18n.new("en")
		i18n._use_threads = threaded and OS.has_feature("threads")
		var err := await i18n.merge_l10n_file_async(CFG_ROOT.path_join("l10n.json"), "en")
		check_eq(err, OK, "l10n.json (threaded: %s): %s" % [threaded, i18n.get_error_message()])
		err = await i18n.merge_l10n_file_async(CFG_ROOT.path_join("l10n.cn.json"), "zh")
		check_eq(err, OK, "l10n.cn.json (threaded: %s): %s" % [threaded, i18n.get_error_message()])
		check_eq(i18n.text("l10n.xlsx|game.title", "zh"), "阿瓦隆传说", "translated")
		check_eq(i18n.text("game|$.tips.login", "zh"), "Welcome back!", "falls back to en")
		check_eq(i18n.get_error_message(), "", "error message after success")

		var fs := MemoryFS.new({"bad.json": "{\"x\": 1}", "invalid.json": "{]", "null.json": "null"})
		check_eq(await i18n.merge_l10n_file_async("null.json", "fr", fs), OK, "null file")
		check(not i18n.get_all_texts().has("fr"), "a null file merges nothing")
		check_eq(await i18n.merge_l10n_file_async("invalid.json", "en", fs), ERR_PARSE_ERROR, "invalid JSON")
		check(i18n.get_error_message().begins_with("<archmage> failed to merge l10n file \"invalid.json\" | "),
				i18n.get_error_message())
		check_eq(await i18n.merge_l10n_file_async("bad.json", "en", fs), ERR_PARSE_ERROR, "bad file")
		check_eq(i18n.get_error_message(), "<archmage> failed to merge l10n file \"bad.json\" | $['x']: expected a string",
				"bad file message")
		check_eq(await i18n.merge_l10n_file_async("missing.json", "en", fs), ERR_FILE_NOT_FOUND, "missing file")
		check_eq(i18n.get_error_message(), "<archmage> failed to read l10n file \"missing.json\": File not found",
				"missing file message")
		check_eq(i18n.text("l10n.xlsx|game.title", "en"), "Legends of Avalon", "texts are kept after failures")


func test_get_text_and_text() -> void:
	# [texts by language, key, lang, text or null]
	var cases := [
		[{"en": {"hello": "Hello"}}, "hello", "en", "Hello"],
		[{"en": {"hello": "Hello"}}, "hello", "zh", "Hello"],
		[{"en": {"hello": "Hello"}, "zh": {"hello": "你好"}}, "hello", "zh", "你好"],
		[{"en": {"hello": "Hello"}}, "goodbye", "en", null],
		[{"ja": {"hello": "こんにちは"}}, "hello", "zh", null],
		[{}, "", "zh", null],
		[{"en": {"welcome": "Welcome"}, "es": {"hello": "Hola"}}, "welcome", "es", "Welcome"],
		[{"en": {"blank": "Blank"}, "zh": {"blank": ""}}, "blank", "zh", ""],
	]
	for c: Array in cases:
		var i18n := I18n.new("en")
		for lang: String in c[0]:
			i18n.merge_texts(c[0][lang], lang)
		check_eq(i18n.get_text(c[1], c[2]), c[3], "get_text(%s, %s)" % [c[1], c[2]])
		check_eq(i18n.text(c[1], c[2]), c[1] if c[3] == null else c[3], "text(%s, %s)" % [c[1], c[2]])


## Looks up the l10n keys of the generated config and enum code with the generated L10n, as the basic test of the Go
## SDK does.
func test_generated_l10n() -> void:
	var atlas := ConfigAtlas.new()
	var loader := Archmage.AtlasLoader.new()
	var opts := Archmage.AtlasOptions.new().with_logger(ScavengerLogger.new()).with_blacklist(["balance"])
	check_eq(loader.load_atlas(CFG_ROOT.path_join("atlas.json"), CFG_ROOT, atlas, opts), OK, loader.get_error_message())
	var i18n := I18n.new("en")
	i18n.merge_l10n_file(CFG_ROOT.path_join("l10n.json"), "en")
	i18n.merge_l10n_file(CFG_ROOT.path_join("l10n.cn.json"), "zh")

	L10n.get_i18n = func() -> Archmage.I18n: return i18n
	L10n.get_preferred_language = func() -> String: return "zh"

	check_eq(atlas.game_cfg.title.get_text("en"), "Legends of Avalon", "game title in en")
	check_eq(atlas.game_cfg.title.text, "阿瓦隆传说", "game title in zh")
	check_eq(atlas.hero_table.lookup(1).name.text, "Arthur Pendragon", "hero 1 name falls back")
	check_eq(atlas.race_table.lookup("Elf").birthplace.text, "Silverwood", "Elf birthplace falls back")
	check_eq(atlas.game_cfg.tips["login"].text, "Welcome back!", "an l10n map value")
	check_eq(atlas.hero_table.lookup(4).name.get_text("zh"), "", "get_text of an empty key")
	check_eq(atlas.hero_table.lookup(4).name.text, "", "text of an empty key")
	check(atlas.hero_table.lookup(4).name == L10n.EMPTY, "an empty l10n value is L10n.EMPTY")
	check_eq(L10n.new("no such key").get_text("zh"), null, "get_text of a missing key")
	check_eq(L10n.new("no such key").text, "no such key", "text of a missing key")
	check_eq(SdkEnum.get_hero_class_l10n_key(SdkEnum.HeroClass.WARRIOR), "enum::HeroClass.Warrior", "Warrior key")
	check_eq(SdkEnum.get_hero_class_l10n_key(SdkEnum.HeroClass.RANGER), "", "Ranger has no key")
	check_eq(L10n.new(SdkEnum.get_hero_class_l10n_key(SdkEnum.HeroClass.WARRIOR)).text, "战士", "Warrior in zh")
	L10n.get_i18n = Callable()
	L10n.get_preferred_language = Callable()


func test_generated_l10n_not_set() -> void:
	capture_errors()
	check_eq(L10n.new("k").text, "k", "text without get_i18n")
	check_eq(L10n.new("k").get_text("en"), null, "get_text without get_i18n")
	check_eq(L10n.EMPTY.text, "", "text of an empty key without get_i18n")
	var i18n := I18n.new("en")
	i18n.merge_texts({"k": "K"}, "en")
	L10n.get_i18n = func() -> Archmage.I18n: return i18n
	check_eq(L10n.new("k").get_text("en"), "K", "get_text without get_preferred_language")
	check_eq(L10n.new("k").text, "k", "text without get_preferred_language")
	L10n.get_i18n = Callable()
	var errors := take_errors()
	check_eq(errors.size(), 3, "errors: %s" % [errors])
	if errors.size() == 3:
		check(errors[0].contains("L10n.get_i18n is not set"), errors[0])
		check(errors[2].contains("L10n.get_preferred_language is not set"), errors[2])


func test_generated_l10n_value() -> void:
	check(L10n.from_json(null) == L10n.EMPTY, "null gives L10n.EMPTY")
	check(L10n.from_json("") == L10n.EMPTY, "an empty string gives L10n.EMPTY")
	var l := L10n.from_json("a.b")
	check_eq(l.key, "a.b", "key")
	check_eq(l.to_json(), "a.b", "to_json")
	check_eq(str(l), "a.b", "str")
	check_eq(Archmage.canonicalize([l]), "[\n\t\"a.b\"\n]\n", "canonicalize")
	capture_errors()
	l.key = "x"
	l.text = "x"
	var errors := take_errors()
	check_eq(l.key, "a.b", "key after assignment")
	check_eq(errors.size(), 2, "errors: %s" % [errors])
