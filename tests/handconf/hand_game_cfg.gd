## The game config (property sheet, variant-mapped). A subset of the fields of testdata/game.json.
class_name HandGameCfg
extends RefCounted

const J = preload("hand_json.gd")

var title: String
var max_level: int
var start_hero: HandHeroTable.HeroCfg
var bgm: String
var starter_items: Array[HandItemTable.ItemCfg] = []
var allowed_classes: Array[int] = []
var level_caps: Array[int] = []
var banned_words: Array[String] = []
var slot_sizes: Array[int] = []
var level_rewards: Dictionary[int, HandItemTable.ItemCfg] = {}
var features: Dictionary[String, bool] = {}

var _start_hero_ref: int
var _starter_items_ref: Array[int] = []
var _level_rewards_ref: Dictionary[int, int] = {}


func load_json(d: Variant) -> String:
	if d == null:
		d = {}
	title = J.s(d.get("title"))
	max_level = J.i(d.get("maxLevel"))
	start_hero = null
	_start_hero_ref = J.i(d.get("startHero"))
	bgm = J.s(d.get("bgm"))
	starter_items.clear()
	_starter_items_ref.clear()
	var a: Variant = d.get("starterItems")
	if a != null:
		for e: Variant in a:
			_starter_items_ref.append(J.i(e))
	allowed_classes.clear()
	a = d.get("allowedClasses")
	if a != null:
		for e: Variant in a:
			allowed_classes.append(J.i(e))
	level_caps.clear()
	a = d.get("levelCaps")
	if a != null:
		for e: Variant in a:
			level_caps.append(J.i(e))
	banned_words.clear()
	a = d.get("bannedWords")
	if a != null:
		for e: Variant in a:
			banned_words.append(J.s(e))
	slot_sizes.clear()
	a = d.get("slotSizes")
	if a != null:
		for e: Variant in a:
			slot_sizes.append(J.i(e))
	level_rewards.clear()
	_level_rewards_ref.clear()
	var m: Variant = d.get("levelRewards")
	if m != null:
		for k: String in m:
			_level_rewards_ref[int(k)] = J.i(m[k])
	features.clear()
	m = d.get("features")
	if m != null:
		for k: String in m:
			features[k] = J.b(m[k])
	return ""


func to_json() -> Dictionary:
	var starter_items_json: Array = []
	for e in starter_items:
		starter_items_json.append(e.id if e != null else 0)
	var level_rewards_json := {}
	for k in level_rewards:
		var e := level_rewards[k]
		level_rewards_json[k] = e.id if e != null else 0
	return {
		"title": title,
		"maxLevel": max_level,
		"startHero": start_hero.id if start_hero != null else 0,
		"bgm": bgm,
		"starterItems": starter_items_json,
		"allowedClasses": allowed_classes,
		"levelCaps": level_caps,
		"bannedWords": banned_words,
		"slotSizes": slot_sizes,
		"levelRewards": level_rewards_json,
		"features": features,
	}


func _bind_refs(atlas: HandConfigAtlas) -> String:
	if _start_hero_ref != 0:
		start_hero = atlas.hero_table.try_lookup(_start_hero_ref)
		if start_hero == null:
			return ".startHero" + HandConfigAtlas._missing("HeroTable", _start_hero_ref)
	starter_items.clear()
	for i in _starter_items_ref.size():
		var ref := _starter_items_ref[i]
		var e: HandItemTable.ItemCfg = null
		if ref != 0:
			e = atlas.item_table.try_lookup(ref)
			if e == null:
				return ".starterItems[%d]%s" % [i, HandConfigAtlas._missing("ItemTable", ref)]
		starter_items.append(e)
	level_rewards.clear()
	for k in _level_rewards_ref:
		var ref := _level_rewards_ref[k]
		var e: HandItemTable.ItemCfg = null
		if ref != 0:
			e = atlas.item_table.try_lookup(ref)
			if e == null:
				return ".levelRewards[%d]%s" % [k, HandConfigAtlas._missing("ItemTable", ref)]
		level_rewards[k] = e
	return ""


func _unbind_refs() -> void:
	start_hero = null
	starter_items.clear()
	level_rewards.clear()
