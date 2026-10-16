## A hand-written ConfigAtlas, shaped like the output of json-gd, for the SDK tests. The class names have the
## prefix Hand so that they do not collide with the generated code in tests/conf.
class_name HandConfigAtlas
extends Archmage.Atlas

## The user-defined config extensions.
var extension := HandAtlasExtension.new()
## The version info of the config repo at export time.
var data_version: Archmage.VersionInfo

var balance_cfg := HandBalanceCfg.new()
var chapter_array := HandChapterArray.new()
var game_cfg := HandGameCfg.new()
var hero_table := HandHeroTable.new()
var item_table := HandItemTable.new()
var race_table := HandRaceTable.new()
var region_table := HandRegionTable.new()
var route_table := HandRouteTable.new()
var skill_table := HandSkillTable.new()

var _items: Dictionary[String, Archmage.AtlasItem] = {
	"balance": Archmage.AtlasItem.new(balance_cfg, Archmage.AtlasItem.MAPPING_VARIANT),
	"chapter": Archmage.AtlasItem.new(chapter_array, Archmage.AtlasItem.MAPPING_UNIQUE),
	"game": Archmage.AtlasItem.new(game_cfg, Archmage.AtlasItem.MAPPING_VARIANT),
	"hero": Archmage.AtlasItem.new(hero_table, Archmage.AtlasItem.MAPPING_UNIQUE),
	"item": Archmage.AtlasItem.new(item_table, Archmage.AtlasItem.MAPPING_UNIQUE),
	"Race": Archmage.AtlasItem.new(race_table, Archmage.AtlasItem.MAPPING_UNIQUE),
	"Region": Archmage.AtlasItem.new(region_table, Archmage.AtlasItem.MAPPING_UNIQUE),
	"route": Archmage.AtlasItem.new(route_table, Archmage.AtlasItem.MAPPING_UNIQUE),
	"skill": Archmage.AtlasItem.new(skill_table, Archmage.AtlasItem.MAPPING_MANY),
}


func atlas_items() -> Dictionary[String, Archmage.AtlasItem]:
	return _items


func set_data_version(version: Archmage.VersionInfo) -> void:
	data_version = version


func bind_refs() -> String:
	var err := ""
	err = chapter_array._bind_refs(self)
	if err != "":
		return "chapter" + err
	err = game_cfg._bind_refs(self)
	if err != "":
		return "game" + err
	err = hero_table._bind_refs(self)
	if err != "":
		return "hero" + err
	err = item_table._bind_refs(self)
	if err != "":
		return "item" + err
	err = race_table._bind_refs(self)
	if err != "":
		return "Race" + err
	err = region_table._bind_refs(self)
	if err != "":
		return "Region" + err
	err = route_table._bind_refs(self)
	if err != "":
		return "route" + err
	err = skill_table._bind_refs(self)
	if err != "":
		return "skill" + err
	return ""


func unbind_refs() -> void:
	chapter_array._unbind_refs()
	game_cfg._unbind_refs()
	hero_table._unbind_refs()
	item_table._unbind_refs()
	race_table._unbind_refs()
	region_table._unbind_refs()
	route_table._unbind_refs()
	skill_table._unbind_refs()


func on_loaded() -> String:
	return extension.on_loaded(self)


## Returns the message of a reference whose ID has no entry in [param table].
static func _missing(table: String, id: Variant) -> String:
	return ": %s: config entry not found for ID %s" % [table, id]
