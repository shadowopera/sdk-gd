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

	static func from_json(d: Variant, pe: Archmage.ParseError) -> ChapterCfg:
		if d is not Dictionary:
			return J.o(d, "HandChapterArray.ChapterCfg", pe)
		var x := ChapterCfg.new()
		x.id = J.s(d.get("id"), pe)
		x.title = J.s(d.get("title"), pe)
		x._hero_ref = J.i(d.get("hero"), pe)
		for e: Variant in J.a(d.get("recommended"), pe):
			x.recommended.append(J.i(e, pe))
		for e: Variant in J.a(d.get("waves"), pe):
			x.waves.append(J.i(e, pe))
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


func load_json(d: Variant) -> String:
	entries.clear()
	var pe := Archmage.ParseError.new()
	for e: Variant in J.a(d, pe):
		entries.append(ChapterCfg.from_json(e, pe))
		if pe.failed or pe.mismatched:
			pe.at("[%d]" % (entries.size() - 1))
			break
	if pe.failed or pe.mismatched:
		return pe.message_at("")
	return ""


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
