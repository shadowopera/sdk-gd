## The Archmage editor plugin (addons/archmage_editor) shows each of these exported properties in the Inspector as a
## dropdown of the IDs of its table.
extends Node

@export_category("Easy Config ID Selection")
@export_custom(CfgIdProp.HINT, CfgIdProp.HERO)
var hero: int = 2
@export_custom(CfgIdProp.HINT, CfgIdProp.RACE)
var race: String = "Elf"
@export_custom(CfgIdProp.HINT, CfgIdProp.HERO_ARRAY)
var heroes: Array[int] = []
@export_custom(CfgIdProp.HINT, CfgIdProp.RACE_ARRAY)
var races: Array[String] = ["Human"]
