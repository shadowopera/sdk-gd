## The region table (regular table, string ID). A subset of the fields of testdata/region.json.
class_name HandRegionTable
extends RefCounted

const J = preload("hand_json.gd")

## The entries, keyed by ID.
var entries: Dictionary[String, RegionCfg] = {}


class RegionCfg extends RefCounted:
	var id: String
	var name: String
	var climate: String
	var neighbors: Array[HandRegionTable.RegionCfg] = []

	var _neighbors_ref: Array[String] = []

	static func from_json(d: Variant, pe: Archmage.ParseError) -> RegionCfg:
		if d is not Dictionary:
			return J.o(d, "HandRegionTable.RegionCfg", pe)
		var x := RegionCfg.new()
		x.name = J.s(d.get("name"), pe)
		x.climate = J.s(d.get("climate"), pe)
		for e: Variant in J.a(d.get("neighbors"), pe):
			x._neighbors_ref.append(J.s(e, pe))
		return x

	func to_json() -> Dictionary:
		var neighbors_json: Array = []
		for e in neighbors:
			neighbors_json.append(e.id if e != null else "")
		return {"id": id, "name": name, "climate": climate, "neighbors": neighbors_json}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		neighbors.clear()
		for i in _neighbors_ref.size():
			var ref := _neighbors_ref[i]
			var e: HandRegionTable.RegionCfg = null
			if ref != "":
				e = atlas.region_table.try_lookup(ref)
				if e == null:
					return ".neighbors[%d]%s" % [i, HandConfigAtlas._missing("RegionTable", ref)]
			neighbors.append(e)
		return ""

	func _unbind_refs() -> void:
		neighbors.clear()


func lookup(id: String) -> RegionCfg:
	if id == "":
		return null
	var e: RegionCfg = entries.get(id)
	if e == null and not entries.has(id):
		push_error("RegionTable: config entry not found for ID %s" % id)
	return e


func try_lookup(id: String) -> RegionCfg:
	return entries.get(id)


func load_json(d: Variant) -> String:
	entries.clear()
	var pe := Archmage.ParseError.new()
	var m := J.m(d, pe)
	for k: String in m:
		entries[k] = RegionCfg.from_json(m[k], pe)
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
