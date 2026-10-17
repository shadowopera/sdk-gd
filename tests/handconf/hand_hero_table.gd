## The hero table (regular table, int ID). A subset of the fields of testdata/hero.json.
class_name HandHeroTable
extends RefCounted

const J = preload("hand_json.gd")

## The entries, keyed by ID.
var entries: Dictionary[int, HeroCfg] = {}


class HeroCfg extends RefCounted:
	var id: int
	var name: String
	var title: String
	var class_: int
	var level: int
	var hp: int
	var gold: int
	var exp: int
	var crit_rate: float
	var dodge: float
	var stats: Stats
	var growth: Stats
	var playable: bool
	var weapon: HandItemTable.ItemCfg
	var weapon_id: int
	var race: HandRaceTable.RaceCfg
	var talents: Array[TalentsEntry] = []

	var _weapon_ref: int
	var _race_ref: String

	static func from_json(d: Variant, pe: Archmage.ParseError) -> HeroCfg:
		if d is not Dictionary:
			return J.o(d, "HandHeroTable.HeroCfg", pe)
		var x := HeroCfg.new()
		x.name = J.s(d.get("name"), pe)
		x.title = J.s(d.get("title"), pe)
		x.class_ = J.i(d.get("class"), pe)
		x.level = J.i(d.get("level"), pe)
		x.hp = J.i(d.get("hp"), pe)
		x.gold = J.i(d.get("gold"), pe)
		x.exp = J.i(d.get("exp"), pe)
		x.crit_rate = J.f(d.get("critRate"), pe)
		x.dodge = J.f(d.get("dodge"), pe)
		x.stats = Stats.from_json(d.get("stats"), pe)
		x.growth = Stats.from_json(d.get("growth"), pe)
		x.playable = J.b(d.get("playable"), pe)
		x._weapon_ref = J.i(d.get("weapon"), pe)
		x.weapon_id = J.i(d.get("weaponId"), pe)
		x._race_ref = J.s(d.get("race"), pe)
		for e: Variant in J.a(d.get("talents"), pe):
			x.talents.append(TalentsEntry.from_json(e, pe))
		return x

	func to_json() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"title": title,
			"class": class_,
			"level": level,
			"hp": hp,
			"gold": gold,
			"exp": exp,
			"critRate": crit_rate,
			"dodge": dodge,
			"stats": stats,
			"growth": growth,
			"playable": playable,
			"weapon": weapon.id if weapon != null else 0,
			"weaponId": weapon_id,
			"race": race.id if race != null else "",
			"talents": talents,
		}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		if _weapon_ref != 0:
			weapon = atlas.item_table.try_lookup(_weapon_ref)
			if weapon == null:
				return ".weapon" + HandConfigAtlas._missing("ItemTable", _weapon_ref)
		if _race_ref != "":
			race = atlas.race_table.try_lookup(_race_ref)
			if race == null:
				return ".race" + HandConfigAtlas._missing("RaceTable", _race_ref)
		for i in talents.size():
			if talents[i] != null:
				var err := talents[i]._bind_refs(atlas)
				if err != "":
					return ".talents[%d]%s" % [i, err]
		return ""

	func _unbind_refs() -> void:
		weapon = null
		race = null
		for e in talents:
			if e != null:
				e._unbind_refs()


class Stats extends RefCounted:
	var hp: int
	var atk: float

	static func from_json(d: Variant, pe: Archmage.ParseError) -> Stats:
		if d is not Dictionary:
			return J.o(d, "HandHeroTable.Stats", pe)
		var x := Stats.new()
		x.hp = J.i(d.get("hp"), pe)
		x.atk = J.f(d.get("atk"), pe)
		return x

	func to_json() -> Dictionary:
		return {"hp": hp, "atk": atk}


class TalentsEntry extends RefCounted:
	var skill: HandSkillTable.SkillCfg
	var tier: int

	var _skill_ref: String

	static func from_json(d: Variant, pe: Archmage.ParseError) -> TalentsEntry:
		if d is not Dictionary:
			return J.o(d, "HandHeroTable.TalentsEntry", pe)
		var x := TalentsEntry.new()
		x._skill_ref = J.s(d.get("skill"), pe)
		x.tier = J.i(d.get("tier"), pe)
		return x

	func to_json() -> Dictionary:
		return {"skill": skill.id if skill != null else "", "tier": tier}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		if _skill_ref != "":
			skill = atlas.skill_table.try_lookup(_skill_ref)
			if skill == null:
				return ".skill" + HandConfigAtlas._missing("SkillTable", _skill_ref)
		return ""

	func _unbind_refs() -> void:
		skill = null


## Returns the entry of [param id]. Reports an error and returns null when there is none; returns null without an
## error for the zero ID.
func lookup(id: int) -> HeroCfg:
	if id == 0:
		return null
	var e: HeroCfg = entries.get(id)
	if e == null and not entries.has(id):
		push_error("HeroTable: config entry not found for ID %d" % id)
	return e


## Returns the entry of [param id], or null when there is none.
func try_lookup(id: int) -> HeroCfg:
	return entries.get(id)


func has(id: int) -> bool:
	return entries.has(id)


func size() -> int:
	return entries.size()


func load_json(d: Variant) -> String:
	entries.clear()
	var pe := Archmage.ParseError.new()
	var m := J.m(d, pe)
	for k: String in m:
		entries[J.k(k, pe)] = HeroCfg.from_json(m[k], pe)
		if pe.failed or pe.mismatched:
			pe.at("[%s]" % k)
			break
	if pe.failed or pe.mismatched:
		return pe.message_at("")
	return ""


## Sets the ID of each entry from its key.
func apply_keys() -> void:
	for id in entries:
		if entries[id] != null:
			entries[id].id = id


func to_json() -> Dictionary:
	return entries


func _bind_refs(atlas: HandConfigAtlas) -> String:
	for id in entries:
		var e := entries[id]
		if e != null:
			var err := e._bind_refs(atlas)
			if err != "":
				return "[%d]%s" % [id, err]
	return ""


func _unbind_refs() -> void:
	for id in entries:
		if entries[id] != null:
			entries[id]._unbind_refs()
