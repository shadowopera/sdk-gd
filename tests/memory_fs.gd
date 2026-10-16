## An in-memory file system for tests: maps each path to its text.
extends Archmage.FS

var files: Dictionary = {}
## Makes file_exists return true for every path, to test a file system whose check is skipped.
var always_exists := false


func _init(p_files: Dictionary = {}, p_always_exists := false) -> void:
	files = p_files
	always_exists = p_always_exists


func read_file(path: String) -> Variant:
	if files.has(path):
		return (files[path] as String).to_utf8_buffer()
	return ERR_FILE_NOT_FOUND


func file_exists(path: String) -> bool:
	return always_exists or files.has(path)


func dir_exists(path: String) -> bool:
	var prefix := path.trim_suffix("/") + "/"
	for p: String in files:
		if p.begins_with(prefix):
			return true
	return false
