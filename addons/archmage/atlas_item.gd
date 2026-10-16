## One item of atlas.json: a config source, the object that holds its data, and its load state.
##
## [b]For the code generator.[/b] [code]ConfigAtlas[/code] creates each item with the object of the config source
## and the mapping of its key in atlas.json:
## [codeblock]
## "hero": Archmage.AtlasItem.new(hero_table, Archmage.AtlasItem.MAPPING_UNIQUE),
## [/codeblock]
extends RefCounted

## The key maps to one file: [code]"unique": {"hero": "hero.json"}[/code].
const MAPPING_UNIQUE := "unique"
## The key maps to several files, one per variant, of which one is loaded:
## [code]"variant": {"game": {"/": "game.json", "dev": "game.dev.json"}}[/code].
const MAPPING_VARIANT := "variant"
## The key maps to a list of files that are merged in order: [code]"many": {"skill": ["a.json", "b.json"]}[/code].
const MAPPING_MANY := "many"
## The variant loaded when [method Archmage.AtlasOptions.with_variant] selects none for the item.
const DEFAULT_VARIANT := "/"

## The object that receives the data. It has these methods:
## [br]- [code]load_json(data: Variant) -> String[/code] fills the object. The loader calls it once, with the parsed
## JSON of all files and overrides of the item merged into one value (see [method Archmage.AtlasLoader.merge_json]).
## Godot parses every number as [float], so convert integers with [code]int()[/code]. A [code]null[/code] or
## missing value gives the default of the field. It returns [code]""[/code], or, for the first invalid value, a
## message that starts with the path of the value in the item, such as [code][3].respawn: invalid duration "abc"[/code];
## the loader then returns [constant ERR_PARSE_ERROR]. [code]Archmage.ParseError[/code] collects such a message.
## [br]- [code]apply_keys() -> void[/code] sets the ID of each entry from its key. Only regular tables have it; the
## loader calls it after [code]load_json[/code] when the object has it.
## [br]- [code]to_json() -> Variant[/code] returns the content as JSON values for [method Archmage.canonicalize]
## and [method Archmage.dump_atlas], with the keys of the config files, such as [code]critRate[/code]. It may
## return nested objects that have their own [code]to_json()[/code]. A reference field is written as its config ID,
## the zero ID when it references nothing.
var cfg: Object
## [constant MAPPING_UNIQUE], [constant MAPPING_VARIANT] or [constant MAPPING_MANY].
var mapping: String
## The key in atlas.json. The loader sets it.
var key := ""
## The variant that the loader loaded for a [constant MAPPING_VARIANT] item; empty for other mappings.
var variant := ""
## Whether the loader has loaded the item.
var ready := false


func _init(p_cfg: Object, p_mapping: String) -> void:
	cfg = p_cfg
	mapping = p_mapping
