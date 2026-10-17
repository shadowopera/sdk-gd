# This file will not be regenerated. Safe to edit.

## The user-defined config extensions of [ConfigAtlas].
class_name AtlasExtension
extends RefCounted

# Put your config extensions here.

## Called after all config data has been loaded and the references between config entries resolved. Returns an
## empty string on success, or an error message that makes the load fail.
@warning_ignore("unused_parameter")
func on_loaded(atlas: ConfigAtlas) -> String:
	# Initialize your config extensions here.
	return ""
