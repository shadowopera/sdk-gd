## The user-edited AtlasExtension of the hand-written conf. Tests set fail_message to make on_loaded fail.
class_name HandAtlasExtension
extends RefCounted

var fail_message := ""
var loaded_count := 0


func on_loaded(atlas: HandConfigAtlas) -> String:
	loaded_count += 1
	return fail_message
