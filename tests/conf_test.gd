## Loads tests/testdata with the config code that json-gd generated in tests/conf.
extends "res://tests/test_case.gd"

const MemoryFS = preload("memory_fs.gd")
const ScavengerLogger = preload("scavenger_logger.gd")

const ATLAS := "res://tests/testdata/atlas.json"
const CFG_ROOT := "res://tests/testdata"
const GOLDEN_DIR := "res://tests/golden"
## The golden files of the Go SDK, relative to the project directory. Only the project directory mode can read them.
const GO_GOLDEN_DIR := "../sdk-go/internal/golden"

## The fields whose types json-gd does not convert yet, per atlas item. Such a field holds the parsed JSON value, so
## the comparison with the Go golden files skips it. In a path, [code]*[/code] matches every key or index.
const UNCONVERTED_FIELDS := {
	"balance": ["spawnInterval"],
	"chapter": ["*.timeLimit"],
	"drop": ["*.gold", "*.bonusRate", "*.despawn", "*.items", "*.coins", "*.titles", "*.rarity", "*.buffTime"],
	"game": ["tickRate", "bgColor", "launchDate", "dailyResets", "classColors", "motd", "bossSpawn", "cameraOffset",
			"gridSize", "tint", "worldBounds"],
	"hero": ["*.birthday", "*.respawn", "*.themeColor", "*.spawnPos", "*.facing"],
	"monster": ["*.speed", "*.aggro", "*.loot"],
	"skill": ["*.cooldown", "*.damage", "*.buffs.*.time"],
}

var logger := ScavengerLogger.new()
var loader := Archmage.AtlasLoader.new()


func opts() -> Archmage.AtlasOptions:
	return Archmage.AtlasOptions.new().with_logger(logger)


## Loads the test atlas and records a failure when the load fails.
func load_ok(o: Archmage.AtlasOptions) -> ConfigAtlas:
	var atlas := ConfigAtlas.new()
	var err := loader.load_atlas(ATLAS, CFG_ROOT, atlas, o)
	check_eq(err, OK, "load_atlas: " + loader.get_error_message())
	return atlas


## Loads the test atlas, expects it to fail with [param code], and returns the error message.
func load_fail(o: Archmage.AtlasOptions, code: Error) -> String:
	var atlas := ConfigAtlas.new()
	var err := loader.load_atlas(ATLAS, CFG_ROOT, atlas, o)
	check_eq(err, code, "load_atlas error code (%s)" % loader.get_error_message())
	return loader.get_error_message()


## Compares each loaded item of [param atlas] with [code]<GOLDEN_DIR>/<golden>/<key>.json[/code] and checks that no
## other golden file exists. Set ARCHMAGE_UPDATE_GOLDEN=1 to write the files instead (project directory mode only).
## Then compares the golden files with the Go golden files, when they can be read.
func check_golden(atlas: ConfigAtlas, golden: String) -> void:
	var dir := GOLDEN_DIR.path_join(golden)
	var items := atlas.atlas_items()
	if OS.get_environment("ARCHMAGE_UPDATE_GOLDEN") == "1":
		DirAccess.make_dir_recursive_absolute(dir)
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		check_eq(Archmage.dump_atlas(atlas, dir), OK, "dump_atlas")
	else:
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
	check_go_golden(golden)


## Compares the values in [code]<GOLDEN_DIR>/<golden>[/code] with the Go golden files of the same case, except
## [constant UNCONVERTED_FIELDS]. Does nothing when the Go golden files cannot be read, as in an exported program.
func check_go_golden(golden: String) -> void:
	var go_dir := ProjectSettings.globalize_path("res://").path_join(GO_GOLDEN_DIR).path_join(golden).simplify_path()
	if not DirAccess.dir_exists_absolute(go_dir):
		print("[conf_test] %s not found; skipped the comparison with the Go golden files" % go_dir)
		return
	var dir := GOLDEN_DIR.path_join(golden)
	var gd_files := Array(DirAccess.get_files_at(dir))
	var go_files := Array(DirAccess.get_files_at(go_dir))
	gd_files.sort()
	go_files.sort()
	check_eq(gd_files, go_files, "golden files of %s" % golden)
	for f: String in gd_files:
		if not go_files.has(f):
			continue
		var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		var want: Variant = JSON.parse_string(FileAccess.get_file_as_string(go_dir.path_join(f)))
		for pattern: String in UNCONVERTED_FIELDS.get(f.get_basename(), []):
			var keys := pattern.split(".")
			got = without(got, keys)
			want = without(want, keys)
		var diff := json_diff(got, want, "%s/%s" % [golden, f])
		check(diff == "", "differs from the Go golden file: " + diff)


## Returns [param value] without the values at the path [param keys].
func without(value: Variant, keys: PackedStringArray) -> Variant:
	if keys.is_empty() or not (value is Dictionary or value is Array):
		return value
	var rest := keys.slice(1)
	if value is Dictionary:
		var d: Dictionary = value.duplicate()
		for k: String in d.keys():
			if keys[0] == "*":
				d[k] = without(d[k], rest)
			elif k == keys[0]:
				if rest.is_empty():
					d.erase(k)
				else:
					d[k] = without(d[k], rest)
		return d
	var a: Array = value.duplicate()
	if keys[0] == "*":
		for i in a.size():
			a[i] = without(a[i], rest)
	return a


## Returns where [param got] and [param want] first differ, or an empty string. A typed array of the generated code
## cannot be null, so null equals an empty array or object.
func json_diff(got: Variant, want: Variant, path: String) -> String:
	if got is Dictionary and want is Dictionary:
		var keys: Array = got.keys()
		for k: Variant in want:
			if not keys.has(k):
				keys.append(k)
		keys.sort()
		for k: Variant in keys:
			if not got.has(k) or not want.has(k):
				return "%s.%s: only in %s" % [path, k, "gd" if got.has(k) else "go"]
			var diff := json_diff(got[k], want[k], "%s.%s" % [path, k])
			if diff != "":
				return diff
		return ""
	if got is Array and want is Array:
		if got.size() != want.size():
			return "%s: %d elements, want %d" % [path, got.size(), want.size()]
		for i in got.size():
			var diff := json_diff(got[i], want[i], "%s[%d]" % [path, i])
			if diff != "":
				return diff
		return ""
	var empty := func(v: Variant) -> bool: return (v is Array or v is Dictionary) and v.is_empty()
	if (got == null and empty.call(want)) or (want == null and empty.call(got)):
		return ""
	if typeof(got) != typeof(want) or got != want:
		return "%s: %s, want %s" % [path, JSON.stringify(got), JSON.stringify(want)]
	return ""


func test_basic() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance"]))
	check_golden(atlas, "basic")

	check_eq(atlas.data_version.semver, "v1.0.0", "data_version.semver")
	check_eq(ConfigAtlas.code_version().short_id, "7f3a2b9", "code_version")
	var items := atlas.atlas_items()
	check(not items["balance"].ready, "balance is skipped")
	for k in ["chapter", "drop", "game", "hero", "item", "monster", "Race", "Region", "route", "skill"]:
		check(items[k].ready, "%s is loaded" % k)

	var arthur := atlas.hero_table.lookup(1)
	check_eq(arthur.id, 1, "hero 1 id")
	check_eq(arthur.name, "l10n.xlsx|hero.arthur", "an l10n field holds the key")
	check_eq(arthur.class_, SdkEnum.HeroClass.WARRIOR, "hero 1 class")
	check_eq(arthur.gold, 999999999999999, "hero 1 gold")
	check_eq(arthur.stats.atk, 88.5, "hero 1 stats.atk")
	check_eq(arthur.respawn, [0.0, 216000.0], "an unconverted field holds the parsed JSON value")
	check(arthur.weapon == atlas.item_table.lookup(101), "hero 1 weapon is item 101")
	check(arthur.race == atlas.race_table.lookup("Human"), "hero 1 race is Human")
	check(arthur.talents[0].skill == atlas.skill_table.lookup("slash"), "hero 1 talent 0 is slash")
	check(atlas.hero_table.lookup(3).weapon == null, "hero 3 has no weapon")
	check(atlas.chapter_array.entries[2].hero == null, "chapter finale has no hero")
	check(atlas.race_table.lookup("Elf").heroes[0] == atlas.hero_table.lookup(2), "Elf heroes")
	check(atlas.route_table.entries["Camelot"]["north"][0][1] == atlas.region_table.lookup("Frostpeak"), "route ref")
	check(atlas.item_table.lookup(101).enchants[1] == null, "a null array element stays null")
	check(atlas.item_table.lookup(102).sell_price == null, "a null object stays null")
	check(atlas.game_cfg.start_hero == arthur, "game start_hero")
	check(atlas.game_cfg.level_rewards[10] == atlas.item_table.lookup(103), "game level_rewards")
	check_eq(atlas.game_cfg.allowed_classes, [SdkEnum.HeroClass.WARRIOR, SdkEnum.HeroClass.MAGE, SdkEnum.HeroClass.RANGER] as Array[SdkEnum.HeroClass], "game allowed_classes")
	check(atlas.monster_table.size() > 0, "monsters are loaded")
	for m: MonsterTable.MonsterCfg in atlas.monster_table:
		for p in m.phases:
			check(p.summon == null or p.summon == atlas.monster_table.lookup(p.summon.id), "monster phase summon")


func test_variant() -> void:
	for v in ["easy", "hard"]:
		var atlas := load_ok(opts().with_whitelist(["balance"]).with_variant("balance", v))
		check_golden(atlas, "variant_" + v)


func test_override_root() -> void:
	var o := opts().with_blacklist(["balance"]) \
			.with_override_root("res://tests/override/1") \
			.with_override_root("res://tests/override/2")
	check_golden(load_ok(o), "override_root")


func test_load_in_place_twice() -> void:
	var atlas := ConfigAtlas.new()
	for i in 2:
		check_eq(loader.load_atlas(ATLAS, CFG_ROOT, atlas, opts().with_blacklist(["balance"])), OK, "load %d" % i)
	check_eq(atlas.game_cfg.starter_items.size(), 2, "game starter_items after two loads")
	check_eq(atlas.game_cfg.banned_words.size(), 0, "game banned_words after two loads")
	check_eq(atlas.extension.on_loaded(atlas), "", "on_loaded")


func test_lookup() -> void:
	var atlas := load_ok(opts().with_blacklist(["balance"]))
	var items := atlas.item_table
	check_eq(items.lookup(101).name, "Excalibur", "lookup 101")
	check(items.lookup(0) == null, "lookup of the zero ID")
	check(items.try_lookup(999) == null, "try_lookup of a missing ID")
	check(atlas.race_table.lookup("") == null, "lookup of the zero string ID")
	check(items.has(101) and not items.has(999), "has")
	check_eq(items.size(), items.entries.size(), "size")
	var ids: Array[int] = []
	for e: ItemTable.ItemCfg in items:
		for f: ItemTable.ItemCfg in items:
			if f == e:
				ids.append(e.id)
	ids.sort()
	var want: Array[int] = items.entries.keys()
	want.sort()
	check_eq(ids, want, "nested iteration over the config entries")

	capture_errors()
	var missing := items.lookup(999)
	var errors := take_errors()
	check(missing == null, "lookup of a missing ID returns null")
	check_eq(errors.size(), 1, "errors of lookup")
	if errors.size() == 1:
		check(errors[0].contains("ItemTable: config entry not found for ID 999"), errors[0])


func test_bind_refs_failure() -> void:
	var cases := {
		"hero.json": ["{\"3\": {\"weapon\": 999}}", "hero[3].weapon: ItemTable: config entry not found for ID 999"],
		"chapter.json": ["[{\"monsters\": [0, 77]}]", "chapter[0].monsters[1]: MonsterTable: config entry not found for ID 77"],
		"game.json": ["{\"levelRewards\": {\"5\": 9}}", "game.levelRewards[5]: ItemTable: config entry not found for ID 9"],
		"route.json": ["{\"Camelot\": {\"north\": [[\"Camelot\", \"Nowhere\"]]}}",
				"route[Camelot][north][0][1]: RegionTable: config entry not found for ID Nowhere"],
		"vtbl/skill-magic.json": ["{\"heal\": {\"buffs\": {\"regen\": {\"source\": 404}}}}",
				"skill[heal].buffs[regen].source: ItemTable: config entry not found for ID 404"],
	}
	for file: String in cases:
		var fs := MemoryFS.new({file: cases[file][0]})
		var msg := load_fail(opts().with_blacklist(["balance"]).with_override_fs(fs), ERR_INVALID_DATA)
		check_eq(msg, "<archmage> failed to bind refs | " + cases[file][1], file)


## Adds the instance ID of each object in [param value] to [param ids], following [code]to_json()[/code], which
## writes a reference as a config ID, so that each object is visited once.
func collect_ids(value: Variant, ids: Array[int]) -> void:
	if value is Object:
		if value != null:
			ids.append(value.get_instance_id())
			collect_ids(value.to_json(), ids)
	elif value is Array or value is Dictionary:
		for e: Variant in (value.values() if value is Dictionary else value):
			collect_ids(e, ids)


## Returns the instance IDs of [param atlas], its items, and the objects of the items.
func atlas_ids(atlas: ConfigAtlas) -> Array[int]:
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
	var weapon_id := arthur.weapon.get_instance_id()
	atlas = null
	check_eq(arthur.title, "  the Once and Future King  ", "hero 1 title")
	check(arthur.weapon == null, "hero 1 weapon is null")
	check(arthur.talents[0].skill == null, "hero 1 talent 0 skill is null")
	check_eq(arthur.to_json()["weapon"], 101, "to_json keeps the config ID of a ref")
	check(not is_instance_id_valid(weapon_id), "the weapon of hero 1 is freed")
