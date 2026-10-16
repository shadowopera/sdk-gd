## The content of atlas.json, which maps each item key to its config files.
##
## The paths are relative to the [code]cfg_root[/code] argument of [method Archmage.AtlasLoader.load_atlas]. An
## atlas modifier (see
## [method Archmage.AtlasOptions.with_atlas_modifier]) may change the maps before the items are loaded:
## [codeblock]
## func modify(aj: Archmage.AtlasJson) -> void:
##     aj.variant["balance"]["/"] = aj.variant["balance"]["hard"]
##     aj.unique.erase("chapter")
## [/codeblock]
extends RefCounted

const VersionInfo = preload("version_info.gd")

## The [code]version[/code] object, or [code]null[/code] when atlas.json has none.
var version: VersionInfo
## Maps a key to its file.
var unique: Dictionary[String, String] = {}
## Maps a key to a [Dictionary] that maps each variant to its file. The variant [code]"/"[/code] is the default.
var variant: Dictionary[String, Dictionary] = {}
## Maps a key to an [code]Array[String][/code] of files, which are merged in order.
var many: Dictionary[String, Array] = {}


## Returns the file of [param variant_name] of [param key], or an empty string when there is none.
func pick_from_variant(key: String, variant_name: String) -> String:
	var files: Dictionary = variant.get(key, {})
	return files.get(variant_name, "")


## Fills this object from [param d], the parsed atlas.json. Returns an empty string, or a message that describes the
## first part of [param d] that does not have the shape of atlas.json.
func _load(d: Variant) -> String:
	if not d is Dictionary:
		return "expected an object"
	var v: Variant = d.get("version")
	if v != null:
		if not v is Dictionary:
			return "$.version: expected an object"
		version = VersionInfo.from_json(v)

	var u: Variant = d.get("unique")
	if u != null:
		if not u is Dictionary:
			return "$.unique: expected an object"
		for k: Variant in u:
			if not u[k] is String:
				return "$.unique['%s']: expected a string" % k
			unique[str(k)] = u[k]

	var va: Variant = d.get("variant")
	if va != null:
		if not va is Dictionary:
			return "$.variant: expected an object"
		for k: Variant in va:
			var cases: Variant = va[k]
			if not cases is Dictionary:
				return "$.variant['%s']: expected an object" % k
			var files: Dictionary[String, String] = {}
			for c: Variant in cases:
				if not cases[c] is String:
					return "$.variant['%s']['%s']: expected a string" % [k, c]
				files[str(c)] = cases[c]
			variant[str(k)] = files

	var m: Variant = d.get("many")
	if m != null:
		if not m is Dictionary:
			return "$.many: expected an object"
		for k: Variant in m:
			var list: Variant = m[k]
			if list == null:
				continue
			if not list is Array:
				return "$.many['%s']: expected an array" % k
			var files: Array[String] = []
			for i in list.size():
				if not list[i] is String:
					return "$.many['%s'][%d]: expected a string" % [k, i]
				files.append(list[i])
			many[str(k)] = files
	return ""
