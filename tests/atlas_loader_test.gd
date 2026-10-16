extends "res://tests/test_case.gd"

const MemoryFS = preload("memory_fs.gd")
const ScavengerLogger = preload("scavenger_logger.gd")

const ATLAS := "res://tests/testdata/atlas.json"
const CFG_ROOT := "res://tests/testdata"
const GOLDEN_DIR := "res://tests/handconf/golden"
## A directory under user:// for files that tests create.
const USER_DIR := "user://archmage_tests"

var logger := ScavengerLogger.new()
var loader := Archmage.AtlasLoader.new()


func opts() -> Archmage.AtlasOptions:
	return Archmage.AtlasOptions.new().with_logger(logger)


## Loads the test atlas and records a failure when the load fails.
func load_ok(o: Archmage.AtlasOptions, atlas_file := ATLAS, cfg_root := CFG_ROOT) -> HandConfigAtlas:
	var atlas := HandConfigAtlas.new()
	var err := loader.load_atlas(atlas_file, cfg_root, atlas, o)
	check_eq(err, OK, "load_atlas: " + loader.get_error_message())
	return atlas


## Loads the test atlas, expects it to fail with [param code], and returns the error message.
func load_fail(o: Archmage.AtlasOptions, code: Error, atlas_file := ATLAS, cfg_root := CFG_ROOT) -> String:
	var atlas := HandConfigAtlas.new()
	var err := loader.load_atlas(atlas_file, cfg_root, atlas, o)
	check_eq(err, code, "load_atlas error code (%s)" % loader.get_error_message())
	return loader.get_error_message()


## Loads the test atlas with [code]load_atlas_async()[/code] and records a failure when the load fails. When
## [param threaded] is false, or the platform has no thread support, the loader takes the path for platforms without
## thread support.
func load_ok_async(o: Archmage.AtlasOptions, threaded: bool, atlas_file := ATLAS, cfg_root := CFG_ROOT) -> HandConfigAtlas:
	var atlas := HandConfigAtlas.new()
	loader._use_threads = threaded and OS.has_feature("threads")
	var err := await loader.load_atlas_async(atlas_file, cfg_root, atlas, o)
	check_eq(err, OK, "load_atlas_async (threaded: %s): %s" % [threaded, loader.get_error_message()])
	return atlas


## Loads the test atlas with [code]load_atlas_async()[/code], expects it to fail with [param code], and returns the
## error message.
func load_fail_async(o: Archmage.AtlasOptions, code: Error, threaded: bool, atlas_file := ATLAS,
		cfg_root := CFG_ROOT) -> String:
	var atlas := HandConfigAtlas.new()
	loader._use_threads = threaded and OS.has_feature("threads")
	var err := await loader.load_atlas_async(atlas_file, cfg_root, atlas, o)
	check_eq(err, code, "load_atlas_async error code (threaded: %s, %s)" % [threaded, loader.get_error_message()])
	return loader.get_error_message()


func check_prefix(message: String, prefix: String) -> void:
	check(message.begins_with(prefix), "expected a message that starts with\n  %s\ngot\n  %s" % [prefix, message])


## Compares each loaded item of [param atlas] with [code]<GOLDEN_DIR>/<golden>/<key>.json[/code] and checks that no
## other golden file exists. Set ARCHMAGE_UPDATE_GOLDEN=1 to write the files instead (project directory mode only).
func check_golden(atlas: HandConfigAtlas, golden: String) -> void:
	var dir := GOLDEN_DIR.path_join(golden)
	var items := atlas.atlas_items()
	if OS.get_environment("ARCHMAGE_UPDATE_GOLDEN") == "1":
		DirAccess.make_dir_recursive_absolute(dir)
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		check_eq(Archmage.dump_atlas(atlas, dir), OK, "dump_atlas")
		return
	var expected := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			expected.append(f.get_basename())
	for key in items:
		if not items[key].ready:
			continue
		var path := dir.path_join(key + ".json")
		check(FileAccess.file_exists(path), "golden file %s does not exist" % path)
		var want := FileAccess.get_file_as_string(path)
		var got := Archmage.canonicalize(items[key].cfg)
		check(got == want, "golden mismatch for %s\ngot:\n%s\nwant:\n%s" % [path, got, want])
		expected.erase(key)
	check(expected.is_empty(), "golden files of items that are not loaded in %s: %s" % [dir, expected])


func test_basic() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance"]))
	check_golden(atlas, "basic")

	check_eq(atlas.data_version.semver, "v1.0.0", "data_version.semver")
	check_eq(atlas.data_version.branch, "", "data_version.branch")
	check_eq(atlas.extension.loaded_count, 1, "on_loaded calls")

	var items := atlas.atlas_items()
	check(not items["balance"].ready, "balance is skipped")
	check_eq(items["hero"].key, "hero", "hero key")
	check_eq(items["game"].variant, "/", "game variant")
	check_eq(items["hero"].variant, "", "hero variant")
	for k in ["chapter", "game", "hero", "item", "Race", "Region", "route", "skill"]:
		check(items[k].ready, "%s is loaded" % k)

	var arthur := atlas.hero_table.lookup(1)
	check_eq(arthur.id, 1, "hero 1 id")
	check_eq(arthur.gold, 999999999999999, "hero 1 gold")
	check(arthur.weapon == atlas.item_table.lookup(101), "hero 1 weapon is item 101")
	check(arthur.race == atlas.race_table.lookup("Human"), "hero 1 race is Human")
	check(arthur.talents[0].skill == atlas.skill_table.lookup("slash"), "hero 1 talent 0 is slash")
	check(atlas.hero_table.lookup(3).weapon == null, "hero 3 has no weapon")
	check(atlas.chapter_array.entries[2].hero == null, "chapter finale has no hero")
	check(atlas.race_table.lookup("Elf").heroes[0] == atlas.hero_table.lookup(2), "Elf heroes")
	check(atlas.route_table.entries["Camelot"]["north"][0][1] == atlas.region_table.lookup("Frostpeak"), "route ref")
	check(atlas.item_table.lookup(101).enchants[1] == null, "a null array element stays null")
	check(atlas.item_table.lookup(102).sell_price == null, "a null object stays null")

	check(logger.lines.has("<archmage> Skipping atlas item: balance. cause: blacklist"), "skip log: %s" % [logger.lines])
	var loaded_line := logger.lines.filter(func(l: String) -> bool: return l.begins_with("<archmage> Loaded 8 atlas items in "))
	check_eq(loaded_line.size(), 1, "summary log line")
	var skill_line := logger.lines.filter(func(l: String) -> bool: return l.begins_with("<archmage> Loaded atlas item \"skill\""))
	check_eq(skill_line.size(), 1, "skill log line")
	if skill_line.size() == 1:
		check_prefix(skill_line[0], "<archmage> Loaded atlas item \"skill\" (mapping=many) from " +
				"res://tests/testdata/vtbl/skill-magic.json, res://tests/testdata/vtbl/skill-melee.json, " +
				"res://tests/testdata/vtbl/skill-passive.json in ")


func test_data_version() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance"]), "res://tests/testdata/atlas_with_version.json")
	var v := atlas.data_version
	check(v != null, "data_version is set")
	if v == null:
		return
	check_eq(v.branch, "main", "branch")
	check_eq(v.semver, "", "semver")
	check_eq(v.short_id, "7f3a2b9", "short_id")
	check_eq(v.timestamp, "2025-02-09T10:23:45Z", "timestamp")
	check_eq(v.tags, [] as Array[String], "tags")
	check_eq(v.status.size(), 1, "status size")


func test_no_data_version() -> void:
	var fs := MemoryFS.new({"a/atlas.json": "{\"unique\": {\"route\": \"route.json\"}}", "a/route.json": "{}"})
	var atlas := load_ok(opts().with_fs(fs).with_whitelist(["route"]), "a/atlas.json", "a")
	check(atlas.data_version == null, "data_version is null when atlas.json has no version")


func test_atlas_modifier() -> void:
	var calls := [0]
	var modifier := func(aj: Archmage.AtlasJson) -> void:
		calls[0] += 1
		aj.variant["balance"]["/"] = aj.variant["balance"]["hard"]
		aj.unique.erase("chapter")
		aj.unique.erase("route")
		aj.variant.erase("game")
	var atlas := load_ok(opts().with_atlas_modifier(modifier).with_blacklist(["chapter", "route", "game"]))
	check_eq(calls[0], 1, "modifier calls")
	check_golden(atlas, "atlas_modifier")


func test_whitelist() -> void:
	var atlas := load_ok(opts().with_whitelist(["hero", "item", "Race", "skill"]))
	check_golden(atlas, "whitelist")
	check(logger.lines.has("<archmage> Skipping atlas item: game. cause: whitelist"), "skip log")


func test_skip_log_before_loading() -> void:
	load_ok(opts().with_blacklist(["balance", "route"]))
	var first_loaded := -1
	for i in logger.lines.size():
		if logger.lines[i].begins_with("<archmage> Loaded atlas item "):
			first_loaded = i
			break
	var route_skipped := logger.lines.find("<archmage> Skipping atlas item: route. cause: blacklist")
	check(route_skipped >= 0 and route_skipped < first_loaded, "skip logs come before load logs: %s" % [logger.lines])


func test_whitelist_ignores_blacklist() -> void:
	var atlas := load_ok(opts().with_whitelist(["hero", "item", "Race", "skill"]).with_blacklist(["hero"]))
	check(atlas.atlas_items()["hero"].ready, "hero is loaded")


func test_whitelist_error() -> void:
	var msg := load_fail(opts().with_whitelist(["item", "balanc"]), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> atlas whitelist: unknown item \"balanc\"")


func test_blacklist() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance", "game", "chapter"]))
	check_golden(atlas, "blacklist")


func test_blacklist_error() -> void:
	var msg := load_fail(opts().with_blacklist(["gm"]), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> atlas blacklist: unknown item \"gm\"")


func test_variant() -> void:
	for v in ["easy", "hard"]:
		var atlas := load_ok(opts().with_whitelist(["balance"]).with_variant("balance", v))
		check_golden(atlas, "variant_" + v)
		check_eq(atlas.atlas_items()["balance"].variant, v, "balance variant")


func test_variant_default() -> void:
	var atlas := load_ok(opts().with_whitelist(["game", "hero", "item", "Race", "skill"]))
	var items := atlas.atlas_items()
	check_eq(items["game"].variant, "/", "game variant")
	check_eq(items["hero"].variant, "", "hero variant")
	check_eq(items["skill"].variant, "", "skill variant")


func test_variant_last_wins() -> void:
	var atlas := load_ok(opts().with_whitelist(["balance"]).with_variant("balance", "easy").with_variant("balance", "hard"))
	check_golden(atlas, "variant_hard")


func test_variant_unknown_item() -> void:
	var msg := load_fail(opts().with_blacklist(["balance"]).with_variant("balanc", "hard"), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> atlas variant: unknown item \"balanc\"")


func test_variant_empty() -> void:
	var msg := load_fail(opts().with_whitelist(["balance"]).with_variant("balance", ""), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> atlas variant: empty variant for item \"balance\"")


func test_variant_not_found() -> void:
	var msg := load_fail(opts().with_whitelist(["balance"]).with_variant("balance", "medium"), ERR_DOES_NOT_EXIST)
	check_eq(msg, "<archmage> failed to load atlas item \"balance\". atlasFile: res://tests/testdata/atlas.json, " +
			"cfgRoot: res://tests/testdata | could not find $.variant['balance']['medium'] in res://tests/testdata/atlas.json")


func test_variant_skipped_item() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance"]).with_variant("balance", "medium").with_variant("hero", "hard"))
	var items := atlas.atlas_items()
	check(not items["balance"].ready, "balance is skipped")
	check_eq(items["hero"].variant, "", "hero variant")


func test_default_variant_not_found() -> void:
	var msg := load_fail(opts(), ERR_DOES_NOT_EXIST)
	check_eq(msg, "<archmage> failed to load atlas item \"balance\". atlasFile: res://tests/testdata/atlas.json, " +
			"cfgRoot: res://tests/testdata | could not find $.variant['balance']['/'] in res://tests/testdata/atlas.json")


func test_unique_not_found() -> void:
	var modifier := func(aj: Archmage.AtlasJson) -> void: aj.unique.erase("hero")
	var msg := load_fail(opts().with_whitelist(["hero"]).with_atlas_modifier(modifier), ERR_DOES_NOT_EXIST)
	check(msg.ends_with("| could not find $.unique['hero'] in res://tests/testdata/atlas.json"), msg)


func test_many_not_found() -> void:
	var modifier := func(aj: Archmage.AtlasJson) -> void: aj.many["skill"] = []
	var msg := load_fail(opts().with_whitelist(["skill"]).with_atlas_modifier(modifier), ERR_DOES_NOT_EXIST)
	check(msg.ends_with("| could not find $.many['skill'] in res://tests/testdata/atlas.json"), msg)


func test_override_root() -> void:
	var o := opts().with_blacklist(["balance"]) \
			.with_override_root("res://tests/override/1") \
			.with_override_root("res://tests/override/2")
	var atlas := load_ok(o)
	check_golden(atlas, "override_root")
	var game_line := logger.lines.filter(func(l: String) -> bool: return l.begins_with("<archmage> Loaded atlas item \"game\""))
	check_eq(game_line.size(), 1, "game log line")
	if game_line.size() == 1:
		check_prefix(game_line[0], "<archmage> Loaded atlas item \"game\" (mapping=variant, variant=/) from " +
				"res://tests/testdata/game.json with 2 overrides in ")


func test_override_root_missing() -> void:
	var msg := load_fail(opts().with_override_root(USER_DIR.path_join("no_such_dir")), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> invalid override root directory \"%s\"" % USER_DIR.path_join("no_such_dir"))


func test_override_root_not_a_directory() -> void:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var path := USER_DIR.path_join("game.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	var msg := load_fail(opts().with_override_root(path), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> override root \"%s\" is not a directory" % path)


func test_override_fs() -> void:
	var fs := MemoryFS.new({
		"game.json": "{\"bgm\":\"audio/night.ogg\",\"levelRewards\":{\"40\":104},\"motd\":{\"item0\":\"Hello\"}}",
		"item.json": "{\"105\":{\"name\":\"Aegis of Camelot\",\"tags\":[\"shield\"]}}",
	})
	var o := opts().with_whitelist(["game", "hero", "item", "Race", "skill"]) \
			.with_override_root("res://tests/override/2") \
			.with_override_fs(fs)
	check_golden(load_ok(o), "override_fs")


func test_override_root_and_fs() -> void:
	check_golden(load_ok(_override_root_and_fs_opts(false)), "override_root_and_fs")


func test_override_fs_file_exists_false_positive() -> void:
	check_golden(load_ok(_override_root_and_fs_opts(true)), "override_root_and_fs")


func _override_root_and_fs_opts(always_exists: bool) -> Archmage.AtlasOptions:
	var fs := MemoryFS.new({
		"vtbl/skill-magic.json": "{\"heal\":{\"mana\":25,\"cooldown\":[0,8]}}",
		"vtbl/skill-passive.json": "{\"aura\":{\"radius\":7}}",
	}, always_exists)
	return opts().with_blacklist(["balance"]) \
			.with_override_root("res://tests/override/1") \
			.with_override_root("res://tests/override/2") \
			.with_override_fs(fs)


func test_override_fs_root() -> void:
	var fs := MemoryFS.new({"patch/game.json": "{\"maxLevel\":99}"})
	var atlas := load_ok(opts().with_whitelist(["game", "hero", "item", "Race", "skill"]).with_override_fs(fs, "patch"))
	check_eq(atlas.game_cfg.max_level, 99, "max_level")


func test_override_fs_root_missing() -> void:
	var fs := MemoryFS.new({"patch/game.json": "{}"})
	var msg := load_fail(opts().with_override_fs(fs, "other"), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> invalid override root directory \"other\"")


func test_override_null_entry() -> void:
	var fs := MemoryFS.new({"hero.json": "{\"4\": null, \"2\": {\"stats\": null, \"talents\": []}}"})
	var atlas := load_ok(opts().with_blacklist(["balance"]).with_override_fs(fs))
	check(atlas.hero_table.has(4), "a null entry keeps its key")
	check(atlas.hero_table.lookup(4) == null, "a null entry is null")
	check(atlas.hero_table.lookup(2).stats == null, "a null object field is null")
	check(atlas.hero_table.lookup(2).talents.is_empty(), "an array is replaced")
	check_eq(atlas.hero_table.lookup(2).growth.hp, 20, "other fields are kept")


func test_with_fs() -> void:
	var fs := MemoryFS.new({
		"testdata/atlas.json": "{\"version\":{\"branch\":\"test-branch\",\"id\":\"123456\"},\"variant\":{\"game\":{\"/\":\"game.json\"}},\"many\":{},\"unique\":{}}",
		"testdata/game.json": "{\"bgm\":\"hello memory fs\",\"maxLevel\":10}",
		"override/game.json": "{\"maxLevel\":99}",
	})
	var atlas := load_ok(opts().with_fs(fs).with_override_root("override").with_whitelist(["game"]), "testdata/atlas.json", "testdata")
	check_eq(atlas.game_cfg.bgm, "hello memory fs", "bgm")
	check_eq(atlas.game_cfg.max_level, 99, "max_level")
	check_eq(atlas.data_version.branch, "test-branch", "branch")
	check_eq(atlas.data_version.id, "123456", "id")


func test_with_fs_override_root_not_found() -> void:
	var msg := load_fail(opts().with_fs(MemoryFS.new()).with_override_root("res://tests/override/1"), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> invalid override root directory \"res://tests/override/1\"")


func test_cfg_root() -> void:
	var fs := MemoryFS.new({
		"meta/atlas.json": "{\"variant\":{\"game\":{\"/\":\"game.json\"}}}",
		"data/game.json": "{\"maxLevel\":7}",
	})
	var atlas := load_ok(opts().with_fs(fs).with_whitelist(["game"]), "meta/atlas.json", "data")
	check_eq(atlas.game_cfg.max_level, 7, "max_level")


func test_many_merge_order() -> void:
	var fs := MemoryFS.new({
		"atlas.json": "{\"many\":{\"skill\":[\"a.json\",\"b.json\"]}}",
		"a.json": "{\"x\":{\"name\":\"A\",\"mana\":1,\"buffs\":{\"b1\":{\"stacks\":1}}},\"y\":{\"name\":\"Y\"}}",
		"b.json": "{\"x\":{\"mana\":2,\"buffs\":{\"b2\":{\"stacks\":2}}}}",
		"ovr/a.json": "{\"x\":{\"mana\":3}}",
		"ovr/b.json": "{\"y\":{\"school\":4}}",
	})
	var atlas := load_ok(opts().with_fs(fs).with_whitelist(["skill"]).with_override_root("ovr"), "atlas.json", "")
	var x := atlas.skill_table.lookup("x")
	check_eq(x.name, "A", "x.name from a.json")
	check_eq(x.mana, 3, "x.mana: the override of a.json is applied after b.json")
	check_eq(x.buffs.keys(), ["b1", "b2"], "x.buffs merged")
	check_eq(atlas.skill_table.lookup("y").school, 4, "y.school")


func test_atlas_file_not_found() -> void:
	var msg := load_fail(opts(), ERR_FILE_NOT_FOUND, "res://tests/testdata/nonexistent_atlas.json")
	check_eq(msg, "<archmage> failed to read \"res://tests/testdata/nonexistent_atlas.json\": File not found")


func test_invalid_atlas_json() -> void:
	var msg := load_fail(opts(), ERR_PARSE_ERROR, "res://tests/testdata/atlas_invalid.json")
	check_prefix(msg, "<archmage> invalid \"res://tests/testdata/atlas_invalid.json\" | ")
	check(msg.ends_with(" at line 1"), msg)


func test_invalid_atlas_shape() -> void:
	for text: String in ["[]", "{\"unique\":[]}", "{\"unique\":{\"a\":1}}", "{\"variant\":{\"a\":\"x\"}}",
			"{\"many\":{\"a\":\"x\"}}", "{\"many\":{\"a\":[1]}}", "{\"version\":\"v1\"}"]:
		var fs := MemoryFS.new({"atlas.json": text})
		var msg := load_fail(opts().with_fs(fs), ERR_PARSE_ERROR, "atlas.json", "")
		check_prefix(msg, "<archmage> invalid \"atlas.json\" | ")


func test_config_file_not_found() -> void:
	var modifier := func(aj: Archmage.AtlasJson) -> void: aj.unique["item"] = "nonexistent/item.json"
	var msg := load_fail(opts().with_atlas_modifier(modifier).with_blacklist(["balance"]), ERR_FILE_NOT_FOUND)
	check_eq(msg, "<archmage> failed to load atlas item \"item\". atlasFile: res://tests/testdata/atlas.json, " +
			"cfgRoot: res://tests/testdata | failed to read \"res://tests/testdata/nonexistent/item.json\": File not found")


func test_invalid_config_json() -> void:
	var fs := MemoryFS.new({"atlas.json": "{\"unique\":{\"item\":\"item.json\"}}", "item.json": "{\"101\": }"})
	var msg := load_fail(opts().with_fs(fs).with_whitelist(["item"]), ERR_PARSE_ERROR, "atlas.json", "")
	check_prefix(msg, "<archmage> failed to load atlas item \"item\". atlasFile: atlas.json, cfgRoot:  | " +
			"failed to parse \"item.json\" | ")


func test_invalid_override_json() -> void:
	var fs := MemoryFS.new({"item.json": "{invalid json}"})
	var msg := load_fail(opts().with_whitelist(["item"]).with_override_fs(fs), ERR_PARSE_ERROR)
	check_prefix(msg, "<archmage> failed to load atlas item \"item\". atlasFile: res://tests/testdata/atlas.json, " +
			"cfgRoot: res://tests/testdata | failed to apply override \"item.json\" | ")


func test_override_read_error() -> void:
	var fs := FailingFS.new()
	var msg := load_fail(opts().with_whitelist(["item"]).with_override_fs(fs), ERR_FILE_CANT_READ)
	check(msg.ends_with("| failed to read override file \"item.json\": %s" % error_string(ERR_FILE_CANT_READ)), msg)


## An override file system whose files exist but cannot be read.
class FailingFS extends Archmage.FS:
	func read_file(_path: String) -> Variant:
		return ERR_FILE_CANT_READ


func test_bind_refs_failure() -> void:
	var fs := MemoryFS.new({"hero.json": "{\"3\": {\"weapon\": 999}}"})
	var msg := load_fail(opts().with_blacklist(["balance"]).with_override_fs(fs), ERR_INVALID_DATA)
	check_eq(msg, "<archmage> failed to bind refs | hero[3].weapon: ItemTable: config entry not found for ID 999")


func test_bind_refs_failure_nested() -> void:
	var fs := MemoryFS.new({"hero.json": "{\"1\": {\"talents\": [{\"skill\": \"slash\"}, {\"skill\": \"nope\"}]}}"})
	var msg := load_fail(opts().with_blacklist(["balance"]).with_override_fs(fs), ERR_INVALID_DATA)
	check_eq(msg, "<archmage> failed to bind refs | hero[1].talents[1].skill: SkillTable: config entry not found for ID nope")


func test_bind_refs_skipped_table() -> void:
	# The item table is skipped, so the weapon of hero 1 has no entry.
	var msg := load_fail(opts().with_whitelist(["hero"]), ERR_INVALID_DATA)
	check_eq(msg, "<archmage> failed to bind refs | hero[1].weapon: ItemTable: config entry not found for ID 101")


func test_on_loaded_failure() -> void:
	var atlas := HandConfigAtlas.new()
	atlas.extension.fail_message = "the extension failed"
	var err := loader.load_atlas(ATLAS, CFG_ROOT, atlas, opts().with_blacklist(["balance"]))
	check_eq(err, FAILED, "error code")
	check_eq(loader.get_error_message(), "the extension failed")


func test_error_message_reset() -> void:
	load_fail(opts().with_blacklist(["gm"]), ERR_INVALID_PARAMETER)
	load_ok(opts().with_blacklist(["balance"]))
	check_eq(loader.get_error_message(), "", "message after a successful load")


func test_invalid_options() -> void:
	var msg := load_fail(opts().with_override_root(" "), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> invalid options: with_override_root: dir is empty")
	msg = load_fail(opts().with_max_concurrency(0).with_fs(null), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> invalid options: with_max_concurrency: n must be at least 1, got 0")
	msg = load_fail(opts().with_atlas_modifier(Callable()), ERR_INVALID_PARAMETER)
	check_eq(msg, "<archmage> invalid options: with_atlas_modifier: modifier is not a valid Callable")


func test_null_atlas() -> void:
	var err := loader.load_atlas(ATLAS, CFG_ROOT, null, opts())
	check_eq(err, ERR_INVALID_PARAMETER, "error code")
	check_eq(loader.get_error_message(), "<archmage> atlas is null")


func test_unsupported_mapping() -> void:
	var atlas := HandConfigAtlas.new()
	atlas.atlas_items()["route"].mapping = "single"
	var err := loader.load_atlas(ATLAS, CFG_ROOT, atlas, opts().with_whitelist(["route"]))
	check_eq(err, ERR_INVALID_DATA, "error code")
	check(loader.get_error_message().ends_with("| unsupported mapping: single"), loader.get_error_message())


func test_lookup() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance"]))
	check_eq(atlas.item_table.lookup(101).name, "Excalibur", "lookup 101")
	check(atlas.item_table.lookup(0) == null, "lookup of the zero ID")
	check(atlas.item_table.try_lookup(999) == null, "try_lookup of a missing ID")
	check(atlas.race_table.try_lookup("Orc") == null, "try_lookup of a missing string ID")

	capture_errors()
	var missing := atlas.item_table.lookup(999)
	var errors := take_errors()
	check(missing == null, "lookup of a missing ID returns null")
	check_eq(errors.size(), 1, "errors of lookup")
	if errors.size() == 1:
		check(errors[0].contains("ItemTable: config entry not found for ID 999"), errors[0])


func test_dump_atlas() -> void:
	var atlas := load_ok(opts().with_whitelist(["balance"]).with_variant("balance", "easy"))
	var dir := USER_DIR.path_join("dump")
	check_eq(Archmage.dump_atlas(atlas, dir), OK, "dump_atlas")
	check_eq(FileAccess.get_file_as_string(dir.path_join("balance.json")), Archmage.canonicalize(atlas.balance_cfg), "balance.json")
	check(not FileAccess.file_exists(dir.path_join("hero.json")), "a skipped item is not dumped")


## Adds the instance ID of each object in [param value] to [param ids], following [code]to_json()[/code], which
## writes a reference as an ID, so that each object is visited once.
func collect_ids(value: Variant, ids: Array[int]) -> void:
	if value is Object:
		if value != null:
			ids.append(value.get_instance_id())
			collect_ids(value.to_json(), ids)
	elif value is Array or value is Dictionary:
		for e: Variant in (value.values() if value is Dictionary else value):
			collect_ids(e, ids)


## Returns the instance IDs of [param atlas], its items, and the objects of the items.
func atlas_ids(atlas: HandConfigAtlas) -> Array[int]:
	var ids: Array[int] = [atlas.get_instance_id()]
	for item: Archmage.AtlasItem in atlas.atlas_items().values():
		ids.append(item.get_instance_id())
		collect_ids(item.cfg, ids)
	return ids


func test_drop_atlas_frees_entries() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance"]))
	# Why a helper? The array that a for loop iterates stays referenced until the function returns.
	var ids := atlas_ids(atlas)
	check(ids.size() > 50, "objects found: %d" % ids.size())
	atlas = null
	var alive := ids.filter(func(id: int) -> bool: return is_instance_id_valid(id))
	check_eq(alive.size(), 0, "objects alive after the atlas is dropped")


func test_drop_atlas_keeps_held_entry() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance"]))
	var arthur := atlas.hero_table.lookup(1)
	var elf := atlas.race_table.lookup("Elf")
	check(arthur.weapon != null and arthur.race != null and arthur.talents[0].skill != null, "hero 1 refs are bound")
	check(not elf.heroes.is_empty(), "Elf heroes are bound")
	var weapon_id := arthur.weapon.get_instance_id()
	atlas = null
	check_eq(arthur.name, "l10n.xlsx|hero.arthur", "hero 1 name")
	check_eq(arthur.talents.size(), 2, "hero 1 talents")
	check(arthur.weapon == null, "hero 1 weapon is null")
	check(arthur.race == null, "hero 1 race is null")
	check(arthur.talents[0].skill == null, "hero 1 talent 0 skill is null")
	check(elf.heroes.is_empty(), "Elf heroes are cleared")
	check(not is_instance_id_valid(weapon_id), "the weapon of hero 1 is freed")


## A file system that reads with FileAccessFS and records the threads on which read_file runs and how many calls
## overlap.
class ProbeFS extends Archmage.FileAccessFS:
	## How long each read_file call waits before it reads, so that calls on worker threads overlap.
	var delay_msec := 0
	var paths: Array[String] = []
	var main_thread_reads := 0
	var worker_thread_reads := 0
	var max_overlap := 0
	var _overlap := 0
	var _mutex := Mutex.new()

	func read_file(path: String) -> Variant:
		_mutex.lock()
		paths.append(path)
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			main_thread_reads += 1
		else:
			worker_thread_reads += 1
		_overlap += 1
		max_overlap = maxi(max_overlap, _overlap)
		_mutex.unlock()
		if delay_msec > 0:
			OS.delay_msec(delay_msec)
		var res: Variant = super.read_file(path)
		_mutex.lock()
		_overlap -= 1
		_mutex.unlock()
		return res


func test_async_basic() -> void:
	for threaded: bool in [true, false]:
		logger.lines.clear()
		var atlas: HandConfigAtlas = await load_ok_async(opts().with_blacklist(["balance"]), threaded)
		check_golden(atlas, "basic")
		check_eq(atlas.data_version.semver, "v1.0.0", "data_version.semver")
		check_eq(atlas.extension.loaded_count, 1, "on_loaded calls")
		var items := atlas.atlas_items()
		check(not items["balance"].ready, "balance is skipped")
		check_eq(items["game"].variant, "/", "game variant")
		var arthur := atlas.hero_table.lookup(1)
		check(arthur.weapon == atlas.item_table.lookup(101), "hero 1 weapon is item 101")
		check(atlas.race_table.lookup("Elf").heroes[0] == atlas.hero_table.lookup(2), "Elf heroes")
		check(logger.lines.has("<archmage> Skipping atlas item: balance. cause: blacklist"), "skip log: %s" % [logger.lines])
		var loaded_line := logger.lines.filter(func(l: String) -> bool: return l.begins_with("<archmage> Loaded 8 atlas items in "))
		check_eq(loaded_line.size(), 1, "summary log line")
		var item_lines := logger.lines.filter(func(l: String) -> bool: return l.begins_with("<archmage> Loaded atlas item "))
		check_eq(item_lines.size(), 8, "item log lines")


func test_async_worker_threads() -> void:
	if not OS.has_feature("threads"):
		print("[atlas_loader_test] no thread support; skipped test_async_worker_threads")
		return
	for n: int in [1, 2]:
		var fs := ProbeFS.new()
		fs.delay_msec = 20
		var atlas: HandConfigAtlas = await load_ok_async(opts().with_fs(fs).with_blacklist(["balance"]).with_max_concurrency(n), true)
		check_golden(atlas, "basic")
		check_eq(fs.main_thread_reads, 0, "reads on the main thread (max concurrency %d)" % n)
		check_eq(fs.worker_thread_reads, fs.paths.size(), "reads on worker threads (max concurrency %d)" % n)
		check(fs.max_overlap <= n, "overlapping reads: %d, max concurrency: %d" % [fs.max_overlap, n])


func test_async_main_thread() -> void:
	var fs := ProbeFS.new()
	var frame := Engine.get_process_frames()
	var atlas: HandConfigAtlas = await load_ok_async(opts().with_fs(fs).with_blacklist(["balance"]), false)
	check_golden(atlas, "basic")
	check_eq(fs.worker_thread_reads, 0, "reads on worker threads")
	check_eq(fs.main_thread_reads, fs.paths.size(), "reads on the main thread")
	var frames := Engine.get_process_frames() - frame
	check(frames >= 8, "frames for 8 items: %d" % frames)


func test_async_errors() -> void:
	for threaded: bool in [true, false]:
		var msg: String = await load_fail_async(opts(), ERR_FILE_NOT_FOUND, threaded, "res://tests/testdata/nonexistent_atlas.json")
		check_eq(msg, "<archmage> failed to read \"res://tests/testdata/nonexistent_atlas.json\": File not found")

		msg = await load_fail_async(opts(), ERR_PARSE_ERROR, threaded, "res://tests/testdata/atlas_invalid.json")
		check_prefix(msg, "<archmage> invalid \"res://tests/testdata/atlas_invalid.json\" | ")

		msg = await load_fail_async(opts().with_max_concurrency(0), ERR_INVALID_PARAMETER, threaded)
		check_eq(msg, "<archmage> invalid options: with_max_concurrency: n must be at least 1, got 0")

		msg = await load_fail_async(opts().with_whitelist(["gm"]), ERR_INVALID_PARAMETER, threaded)
		check_eq(msg, "<archmage> atlas whitelist: unknown item \"gm\"")

		var modifier := func(aj: Archmage.AtlasJson) -> void: aj.unique["item"] = "nonexistent/item.json"
		msg = await load_fail_async(opts().with_atlas_modifier(modifier).with_blacklist(["balance"]), ERR_FILE_NOT_FOUND, threaded)
		check_eq(msg, "<archmage> failed to load atlas item \"item\". atlasFile: res://tests/testdata/atlas.json, " +
				"cfgRoot: res://tests/testdata | failed to read \"res://tests/testdata/nonexistent/item.json\": File not found")

		var modifier2 := func(aj: Archmage.AtlasJson) -> void: aj.many["skill"] = []
		msg = await load_fail_async(opts().with_whitelist(["skill"]).with_atlas_modifier(modifier2), ERR_DOES_NOT_EXIST, threaded)
		check(msg.ends_with("| could not find $.many['skill'] in res://tests/testdata/atlas.json"), msg)

		var fs := MemoryFS.new({"item.json": "{invalid json}"})
		msg = await load_fail_async(opts().with_whitelist(["item"]).with_override_fs(fs), ERR_PARSE_ERROR, threaded)
		check_prefix(msg, "<archmage> failed to load atlas item \"item\". atlasFile: res://tests/testdata/atlas.json, " +
				"cfgRoot: res://tests/testdata | failed to apply override \"item.json\" | ")

		fs = MemoryFS.new({"hero.json": "{\"3\": {\"weapon\": 999}}"})
		msg = await load_fail_async(opts().with_blacklist(["balance"]).with_override_fs(fs), ERR_INVALID_DATA, threaded)
		check_eq(msg, "<archmage> failed to bind refs | hero[3].weapon: ItemTable: config entry not found for ID 999")

		loader._use_threads = threaded and OS.has_feature("threads")
		var atlas := HandConfigAtlas.new()
		atlas.atlas_items()["route"].mapping = "single"
		check_eq(await loader.load_atlas_async(ATLAS, CFG_ROOT, atlas, opts().with_whitelist(["route"])), ERR_INVALID_DATA,
				"unsupported mapping")
		check(loader.get_error_message().ends_with("| unsupported mapping: single"), loader.get_error_message())

		atlas = HandConfigAtlas.new()
		atlas.extension.fail_message = "the extension failed"
		check_eq(await loader.load_atlas_async(ATLAS, CFG_ROOT, atlas, opts().with_blacklist(["balance"])), FAILED,
				"on_loaded failure")
		check_eq(loader.get_error_message(), "the extension failed")

		check_eq(await loader.load_atlas_async(ATLAS, CFG_ROOT, null, opts()), ERR_INVALID_PARAMETER, "null atlas")
		check_eq(loader.get_error_message(), "<archmage> atlas is null")


func test_async_failure_stops_loading() -> void:
	for threaded: bool in [true, false]:
		var fs := ProbeFS.new()
		var modifier := func(aj: Archmage.AtlasJson) -> void: aj.unique["hero"] = "nonexistent/hero.json"
		var o := opts().with_fs(fs).with_blacklist(["balance"]).with_atlas_modifier(modifier).with_max_concurrency(1)
		var atlas := HandConfigAtlas.new()
		loader._use_threads = threaded and OS.has_feature("threads")
		check_eq(await loader.load_atlas_async(ATLAS, CFG_ROOT, atlas, o), ERR_FILE_NOT_FOUND, "error code")
		var items := atlas.atlas_items()
		for k in ["chapter", "game"]:
			check(items[k].ready, "%s is loaded before the failure" % k)
		for k in ["hero", "item", "Race", "Region", "route", "skill"]:
			check(not items[k].ready, "%s is not loaded" % k)
		check(not fs.paths.has("res://tests/testdata/item.json"), "item.json is not read: %s" % [fs.paths])
		check_eq(atlas.extension.loaded_count, 0, "on_loaded calls")

		# The loader and the atlas can load again.
		check_eq(await loader.load_atlas_async(ATLAS, CFG_ROOT, atlas, opts().with_blacklist(["balance"])), OK, "reload")
		check_golden(atlas, "basic")


signal _background_load_done
var _background_load_err := -1


func _background_load(p_loader: Archmage.AtlasLoader, atlas: HandConfigAtlas, o: Archmage.AtlasOptions) -> void:
	_background_load_err = await p_loader.load_atlas_async(ATLAS, CFG_ROOT, atlas, o)
	_background_load_done.emit()


func test_async_busy() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var atlas := HandConfigAtlas.new()
	# Why call_deferred? GDScript does not let a function start a coroutine without awaiting it.
	_background_load.call_deferred(loader, atlas, opts().with_blacklist(["balance"]))
	for i in 10:
		if loader._busy:
			break
		await tree.process_frame
	check(loader._busy, "the background load is running")

	check_eq(loader.load_atlas(ATLAS, CFG_ROOT, HandConfigAtlas.new(), opts()), ERR_BUSY, "load_atlas of a busy loader")
	check_eq(await loader.load_atlas_async(ATLAS, CFG_ROOT, HandConfigAtlas.new(), opts()), ERR_BUSY,
			"load_atlas_async of a busy loader")
	check_eq(loader.get_error_message(), "", "the message of the running load")

	var other := Archmage.AtlasLoader.new()
	check_eq(other.load_atlas(ATLAS, CFG_ROOT, atlas, opts()), ERR_BUSY, "load_atlas of an atlas being loaded")
	check_eq(other.get_error_message(), "<archmage> another loader is loading the atlas")
	check_eq(await other.load_atlas_async(ATLAS, CFG_ROOT, atlas, opts()), ERR_BUSY,
			"load_atlas_async of an atlas being loaded")

	if _background_load_err == -1:
		await _background_load_done
	check_eq(_background_load_err, OK, "background load: " + loader.get_error_message())
	check_golden(atlas, "basic")
	check_eq(atlas.extension.loaded_count, 1, "on_loaded calls")
	check_eq(other.load_atlas(ATLAS, CFG_ROOT, HandConfigAtlas.new(), opts().with_blacklist(["balance"])), OK,
			"load after the background load")


func test_async_without_loader_reference() -> void:
	var atlas := HandConfigAtlas.new()
	var err := await Archmage.AtlasLoader.new().load_atlas_async(ATLAS, CFG_ROOT, atlas, opts().with_blacklist(["balance"]))
	check_eq(err, OK, "load_atlas_async")
	check_golden(atlas, "basic")


func test_async_drop_atlas_frees_entries() -> void:
	for threaded: bool in [true, false]:
		var atlas: HandConfigAtlas = await load_ok_async(opts().with_blacklist(["balance"]), threaded)
		var ids := atlas_ids(atlas)
		check(ids.size() > 50, "objects found: %d" % ids.size())
		atlas = null
		# Why wait a frame? This function resumes inside the call that completes the load, and that call still
		# references the atlas until this function awaits.
		await (Engine.get_main_loop() as SceneTree).process_frame
		var alive := ids.filter(func(id: int) -> bool: return is_instance_id_valid(id))
		check_eq(alive.size(), 0, "objects alive after the atlas is dropped (threaded: %s)" % threaded)
