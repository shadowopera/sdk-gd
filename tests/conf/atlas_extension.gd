# This file will not be regenerated. Safe to edit.

## The user-defined config extensions of [ConfigAtlas].
class_name AtlasExtension
extends RefCounted

## The message that on_loaded returns. Tests set it to make the load fail.
var fail_message := ""
## The number of on_loaded calls.
var loaded_count := 0


## Called after all config data has been loaded and the references between config entries resolved. Returns an
## empty string on success, or an error message that makes the load fail.
@warning_ignore("unused_parameter")
func on_loaded(atlas: ConfigAtlas) -> String:
	loaded_count += 1
	return fail_message
