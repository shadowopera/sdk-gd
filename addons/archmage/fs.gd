## The file system from which the loader reads atlas.json, the config files and the override files.
##
## Extend this class to read files from elsewhere, such as from memory. [Archmage.FileAccessFS] is the default.
## [method file_exists] and [method dir_exists] return [code]true[/code] unless overridden; keep that default when
## checking is not possible or is expensive.
## [br][br]
## [method Archmage.AtlasLoader.load_atlas_async] calls [method read_file] and [method file_exists] on worker threads,
## several at a time, so an implementation must be safe to call that way. Protect any state that the calls share,
## such as one [ZIPReader] used for all reads, with a [Mutex]. [method dir_exists] runs on the thread that starts the
## load.
@abstract
extends RefCounted


## Returns the content of the file at [param path] as a [PackedByteArray], or an [enum Error] code when the file
## cannot be read. Return [constant ERR_FILE_NOT_FOUND] when the file does not exist: the loader skips an override
## file for which [method file_exists] returned [code]true[/code] only when it gets this code.
@abstract func read_file(path: String) -> Variant


## Returns whether the file at [param path] exists. The loader calls it for each possible override file and reads
## only the files that exist.
func file_exists(_path: String) -> bool:
	return true


## Returns whether the directory at [param path] exists. The loader calls it for each override root and fails when
## it returns [code]false[/code].
func dir_exists(_path: String) -> bool:
	return true
