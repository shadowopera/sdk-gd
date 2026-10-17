## The skill table (regular table, string ID, many-mapped). A subset of the fields of testdata/vtbl/skill-*.json.
class_name HandSkillTable
extends RefCounted

const J = preload("hand_json.gd")

## The entries, keyed by ID.
var entries: Dictionary[String, SkillCfg] = {}


class SkillCfg extends RefCounted:
	var id: String
	var name: String
	var mana: int
	var school: int
	var src: String
	var buffs: Dictionary[String, BuffsEntry] = {}
	var radius: float

	static func from_json(d: Variant, pe: Archmage.ParseError) -> SkillCfg:
		if d is not Dictionary:
			return J.o(d, "HandSkillTable.SkillCfg", pe)
		var x := SkillCfg.new()
		x.name = J.s(d.get("name"), pe)
		x.mana = J.i(d.get("mana"), pe)
		x.school = J.i(d.get("school"), pe)
		x.src = J.s(d.get("src"), pe)
		var m := J.m(d.get("buffs"), pe)
		for k: String in m:
			x.buffs[k] = BuffsEntry.from_json(m[k], pe)
		x.radius = J.f(d.get("radius"), pe)
		return x

	func to_json() -> Dictionary:
		return {"id": id, "name": name, "mana": mana, "school": school, "src": src, "buffs": buffs, "radius": radius}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		for k in buffs:
			if buffs[k] != null:
				var err := buffs[k]._bind_refs(atlas)
				if err != "":
					return ".buffs[%s]%s" % [k, err]
		return ""

	func _unbind_refs() -> void:
		for k in buffs:
			if buffs[k] != null:
				buffs[k]._unbind_refs()


class BuffsEntry extends RefCounted:
	var stacks: int
	var source: HandItemTable.ItemCfg

	var _source_ref: int

	static func from_json(d: Variant, pe: Archmage.ParseError) -> BuffsEntry:
		if d is not Dictionary:
			return J.o(d, "HandSkillTable.BuffsEntry", pe)
		var x := BuffsEntry.new()
		x.stacks = J.i(d.get("stacks"), pe)
		x._source_ref = J.i(d.get("source"), pe)
		return x

	func to_json() -> Dictionary:
		return {"stacks": stacks, "source": source.id if source != null else 0}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		if _source_ref != 0:
			source = atlas.item_table.try_lookup(_source_ref)
			if source == null:
				return ".source" + HandConfigAtlas._missing("ItemTable", _source_ref)
		return ""

	func _unbind_refs() -> void:
		source = null


func lookup(id: String) -> SkillCfg:
	if id == "":
		return null
	var e: SkillCfg = entries.get(id)
	if e == null and not entries.has(id):
		push_error("SkillTable: config entry not found for ID %s" % id)
	return e


func try_lookup(id: String) -> SkillCfg:
	return entries.get(id)


func load_json(d: Variant) -> String:
	entries.clear()
	var pe := Archmage.ParseError.new()
	var m := J.m(d, pe)
	for k: String in m:
		entries[k] = SkillCfg.from_json(m[k], pe)
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
