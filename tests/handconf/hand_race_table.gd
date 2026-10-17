## The race table (regular table, string ID). The fields of testdata/race.json.
class_name HandRaceTable
extends RefCounted

const J = preload("hand_json.gd")

## The entries, keyed by ID.
var entries: Dictionary[String, RaceCfg] = {}


class RaceCfg extends RefCounted:
	var id: String
	var birthplace: String
	var heroes: Array[HandHeroTable.HeroCfg] = []
	var hero_ids: Array[int] = []

	var _heroes_ref: Array[int] = []

	static func from_json(d: Variant, pe: Archmage.ParseError) -> RaceCfg:
		if d is not Dictionary:
			return J.o(d, "HandRaceTable.RaceCfg", pe)
		var x := RaceCfg.new()
		x.birthplace = J.s(d.get("birthplace"), pe)
		for e: Variant in J.a(d.get("heroes"), pe):
			x._heroes_ref.append(J.i(e, pe))
		for e: Variant in J.a(d.get("heroIds"), pe):
			x.hero_ids.append(J.i(e, pe))
		return x

	func to_json() -> Dictionary:
		var heroes_json: Array = []
		for e in heroes:
			heroes_json.append(e.id if e != null else 0)
		return {"id": id, "birthplace": birthplace, "heroes": heroes_json, "heroIds": hero_ids}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		heroes.clear()
		for i in _heroes_ref.size():
			var ref := _heroes_ref[i]
			var e: HandHeroTable.HeroCfg = null
			if ref != 0:
				e = atlas.hero_table.try_lookup(ref)
				if e == null:
					return ".heroes[%d]%s" % [i, HandConfigAtlas._missing("HeroTable", ref)]
			heroes.append(e)
		return ""

	func _unbind_refs() -> void:
		heroes.clear()


func lookup(id: String) -> RaceCfg:
	if id == "":
		return null
	var e: RaceCfg = entries.get(id)
	if e == null and not entries.has(id):
		push_error("RaceTable: config entry not found for ID %s" % id)
	return e


func try_lookup(id: String) -> RaceCfg:
	return entries.get(id)


func load_json(d: Variant) -> String:
	entries.clear()
	var pe := Archmage.ParseError.new()
	var m := J.m(d, pe)
	for k: String in m:
		entries[k] = RaceCfg.from_json(m[k], pe)
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
				return "[%s]%s" % [id, err]
	return ""


func _unbind_refs() -> void:
	for id in entries:
		if entries[id] != null:
			entries[id]._unbind_refs()
