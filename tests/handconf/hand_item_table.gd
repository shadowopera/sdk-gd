## The item table (regular table, int ID). The fields of testdata/item.json.
class_name HandItemTable
extends RefCounted

const J = preload("hand_json.gd")

## The entries, keyed by ID.
var entries: Dictionary[int, ItemCfg] = {}


class ItemCfg extends RefCounted:
	var id: int
	var name: String
	var rarity: int
	var price: Price
	var sell_price: Price
	var tags: Array[String] = []
	var icon: String
	var stackable: bool
	var best_owner: HandHeroTable.HeroCfg
	var enchants: Array[EnchantsEntry] = []

	var _best_owner_ref: int

	static func from_json(d: Variant) -> ItemCfg:
		if d == null:
			return null
		var x := ItemCfg.new()
		x.name = J.s(d.get("name"))
		x.rarity = J.i(d.get("rarity"))
		x.price = Price.from_json(d.get("price"))
		x.sell_price = Price.from_json(d.get("sellPrice"))
		var a: Variant = d.get("tags")
		if a != null:
			for e: Variant in a:
				x.tags.append(J.s(e))
		x.icon = J.s(d.get("icon"))
		x.stackable = J.b(d.get("stackable"))
		x._best_owner_ref = J.i(d.get("bestOwner"))
		a = d.get("enchants")
		if a != null:
			for e: Variant in a:
				x.enchants.append(EnchantsEntry.from_json(e))
		return x

	func to_json() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"rarity": rarity,
			"price": price,
			"sellPrice": sell_price,
			"tags": tags,
			"icon": icon,
			"stackable": stackable,
			"bestOwner": best_owner.id if best_owner != null else 0,
			"enchants": enchants,
		}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		if _best_owner_ref != 0:
			best_owner = atlas.hero_table.try_lookup(_best_owner_ref)
			if best_owner == null:
				return ".bestOwner" + HandConfigAtlas._missing("HeroTable", _best_owner_ref)
		for i in enchants.size():
			if enchants[i] != null:
				var err := enchants[i]._bind_refs(atlas)
				if err != "":
					return ".enchants[%d]%s" % [i, err]
		return ""

	func _unbind_refs() -> void:
		best_owner = null
		for e in enchants:
			if e != null:
				e._unbind_refs()


class Price extends RefCounted:
	var gold: int
	var gem: int

	static func from_json(d: Variant) -> Price:
		if d == null:
			return null
		var x := Price.new()
		x.gold = J.i(d.get("gold"))
		x.gem = J.i(d.get("gem"))
		return x

	func to_json() -> Dictionary:
		return {"gold": gold, "gem": gem}


class EnchantsEntry extends RefCounted:
	var element: int
	var bonus: int
	var scroll: HandItemTable.ItemCfg

	var _scroll_ref: int

	static func from_json(d: Variant) -> EnchantsEntry:
		if d == null:
			return null
		var x := EnchantsEntry.new()
		x.element = J.i(d.get("element"))
		x.bonus = J.i(d.get("bonus"))
		x._scroll_ref = J.i(d.get("scroll"))
		return x

	func to_json() -> Dictionary:
		return {"element": element, "bonus": bonus, "scroll": scroll.id if scroll != null else 0}

	func _bind_refs(atlas: HandConfigAtlas) -> String:
		if _scroll_ref != 0:
			scroll = atlas.item_table.try_lookup(_scroll_ref)
			if scroll == null:
				return ".scroll" + HandConfigAtlas._missing("ItemTable", _scroll_ref)
		return ""

	func _unbind_refs() -> void:
		scroll = null


func lookup(id: int) -> ItemCfg:
	if id == 0:
		return null
	var e: ItemCfg = entries.get(id)
	if e == null and not entries.has(id):
		push_error("ItemTable: config entry not found for ID %d" % id)
	return e


func try_lookup(id: int) -> ItemCfg:
	return entries.get(id)


func load_json(d: Variant) -> String:
	entries.clear()
	if d == null:
		return ""
	for k: String in d:
		entries[int(k)] = ItemCfg.from_json(d[k])
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
