## The version metadata of the config repository, from the [code]version[/code] object of atlas.json.
##
## A field that the object does not have is empty.
extends RefCounted

const VersionInfo = preload("version_info.gd")

## The semantic version given with the [code]--semver[/code] flag of archmage.
var semver := ""
## The workspace name.
var workspace := ""
## The tags of the commit.
var tags: Array[String] = []
## The branch name.
var branch := ""
## The full commit ID.
var id := ""
## The abbreviated commit ID.
var short_id := ""
## The commit time in RFC 3339 format, such as [code]2025-02-09T10:23:45Z[/code].
var timestamp := ""
## The commit message.
var message := ""
## The commit author.
var author := ""
## The entries of the working tree status.
var status: Array[String] = []
## Additional metadata.
var extra: Dictionary = {}


## Returns the version info in [param d], a parsed JSON object, or [code]null[/code] when [param d] is not a
## [Dictionary].
static func from_json(d: Variant) -> VersionInfo:
	if not d is Dictionary:
		return null
	var v := VersionInfo.new()
	v.semver = _string(d.get("semver"))
	v.workspace = _string(d.get("workspace"))
	v.tags = _strings(d.get("tags"))
	v.branch = _string(d.get("branch"))
	v.id = _string(d.get("id"))
	v.short_id = _string(d.get("shortId"))
	v.timestamp = _string(d.get("timestamp"))
	v.message = _string(d.get("message"))
	v.author = _string(d.get("author"))
	v.status = _strings(d.get("status"))
	var e: Variant = d.get("extra")
	if e is Dictionary:
		v.extra = e
	return v


## Returns the version info as a JSON object with the keys of atlas.json.
func to_json() -> Dictionary:
	return {
		"semver": semver,
		"workspace": workspace,
		"tags": tags,
		"branch": branch,
		"id": id,
		"shortId": short_id,
		"timestamp": timestamp,
		"message": message,
		"author": author,
		"status": status,
		"extra": extra,
	}


static func _string(v: Variant) -> String:
	return "" if v == null else str(v)


static func _strings(v: Variant) -> Array[String]:
	var a: Array[String] = []
	if v is Array:
		for e: Variant in v:
			a.append(_string(e))
	return a
