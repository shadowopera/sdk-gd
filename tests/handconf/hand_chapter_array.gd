## The chapter array (tree array). A subset of the fields of testdata/chapter.json.
class_name HandChapterArray
extends RefCounted

const J = preload("hand_json.gd")

## The entries, in file order.
var entries: Array[ChapterCfg] = []


class ChapterCfg extends RefCounted:
	var id: String
	var title: String
	var hero: HandHeroTable.HeroCfg
	var recommended: Array[int] = []
	var waves: Array[int] = []

	var _hero_ref: int

	static func from_json(d: Variant) -> ChapterCfg:
		if d == null:
			return null
		var x := ChapterCfg.new()
		x.id = J.s(d.get("id"))
		x.title = J.s(d.get("title"))
		x._hero_ref = J.i(d.get("hero"))
		var a: Variant = d.get("recommended")
		if a != null:
			for e: Variant in a:
				x.recommended.append(J.i(e))
		a = d.get("waves")
		if a != null:
			for e: Variant in a:
				x.waves.append(J.i(e))
		return x

	func to_json() -> Dictionary:
		return {
			"id": id,
			"title": title,
			"hero": hero.id if hero != null else 0,
			"recommended": recommended,
			"waves": waves,
		}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		if _hero_ref != 0:
			hero = atlas.hero_table.try_lookup(_hero_ref)
			if hero == null:
				return ".hero" + HandConfigAtlas._missing("HeroTable", _hero_ref)
		return ""

	func _unbind_refs() -> void:
		hero = null


func load_json(d: Variant) -> void:
	entries.clear()
	if d == null:
		return
	for e: Variant in d:
		entries.append(ChapterCfg.from_json(e))


func to_json() -> Array:
	return entries


func _bind_refs(atlas: HandConfigAtlas) -> String:
	for i in entries.size():
		if entries[i] != null:
			var err := entries[i]._bind_refs(atlas)
			if err != "":
				return "[%d]%s" % [i, err]
	return ""


func _unbind_refs() -> void:
	for e in entries:
		if e != null:
			e._unbind_refs()
