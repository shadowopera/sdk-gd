## Reads files with [FileAccess]. This is the default file system of the loader.
##
## Paths can be [code]res://[/code] paths, [code]user://[/code] paths or absolute paths of the operating system, and
## files in mounted resource packs can be read too. Mount resource packs before loading starts.
extends "fs.gd"


func read_file(path: String) -> Variant:
	var data := FileAccess.get_file_as_bytes(path)
	var err := FileAccess.get_open_error()
	if err == OK:
		return data
	# Why not trust the error code? On Android, a missing file in the APK gives ERR_CANT_OPEN.
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return err


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## Always returns [code]true[/code] for [code]res://[/code] paths, because [DirAccess] does not report them reliably
## after the project is exported or a resource pack is mounted.
func dir_exists(path: String) -> bool:
	if path.begins_with("res://"):
		return true
	return DirAccess.dir_exists_absolute(path)
