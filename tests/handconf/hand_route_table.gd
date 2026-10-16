## The route table (tree map whose values are not objects): map[string]map[string][][]ref Region.
## The inner collections are untyped, as Godot typed collections cannot nest.
class_name HandRouteTable
extends RefCounted

## Maps a region ID to a Dictionary that maps a direction to an Array of Arrays of RegionCfg.
var entries: Dictionary[String, Dictionary] = {}

var _entries_ref: Dictionary[String, Dictionary] = {}


func load_json(d: Variant) -> String:
	entries.clear()
	_entries_ref.clear()
	if d == null:
		return ""
	for k: String in d:
		_entries_ref[k] = {} if d[k] == null else d[k]
	return ""


func to_json() -> Dictionary:
	var out := {}
	for k in entries:
		var dirs := {}
		for dir: String in entries[k]:
			var paths: Array = []
			for path: Array in entries[k][dir]:
				var ids: Array = []
				for r: HandRegionTable.RegionCfg in path:
					ids.append(r.id if r != null else "")
				paths.append(ids)
			dirs[dir] = paths
		out[k] = dirs
	return out


func _bind_refs(atlas: HandConfigAtlas) -> String:
	entries.clear()
	for k in _entries_ref:
		var dirs := {}
		for dir: String in _entries_ref[k]:
			var paths: Array = []
			var raw: Variant = _entries_ref[k][dir]
			if raw != null:
				for i in raw.size():
					var path: Array = []
					if raw[i] != null:
						for j in raw[i].size():
							var ref := str(raw[i][j]) if raw[i][j] != null else ""
							var r: HandRegionTable.RegionCfg = null
							if ref != "":
								r = atlas.region_table.try_lookup(ref)
								if r == null:
									return "[%s][%s][%d][%d]%s" % [k, dir, i, j, HandConfigAtlas._missing("RegionTable", ref)]
							path.append(r)
					paths.append(path)
			dirs[dir] = paths
		entries[k] = dirs
	return ""


func _unbind_refs() -> void:
	entries.clear()
