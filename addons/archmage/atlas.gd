## The base class of the generated [code]ConfigAtlas[/code], which [method Archmage.AtlasLoader.load_atlas] fills.
##
## [b]For the code generator.[/b] [code]ConfigAtlas[/code] extends [code]Archmage.Atlas[/code] and implements the
## abstract methods below. When it is created, it creates one empty object for each config source (a field such
## as [code]var hero_table := HeroTable.new()[/code]) and one [Archmage.AtlasItem] that holds the object and its
## mapping. The loader fills the objects in place, so the fields keep pointing at them; an item that is skipped keeps
## its empty object.
## [br][br]
## The loader calls the methods in this order: [method set_data_version], [method atlas_items], the
## [code]load_json[/code] and [code]apply_keys[/code] methods of each loaded item (see
## [member Archmage.AtlasItem.cfg]), [method bind_refs], then
## [method on_loaded]. Loading stops at the first failure.
## [br][br]
## [b]Threads.[/b] The asynchronous loader may call the [code]load_json[/code] and [code]apply_keys[/code] methods of
## the items on worker threads, for several items at a time; the other methods run on the main thread.
## [br][br]
## [b]Freeing.[/b] When the atlas is freed, it calls [method unbind_refs], which sets the reference fields of all
## entries to [code]null[/code]; without this, entries that reference each other would never be freed. An entry that
## other code still holds stays alive, with its reference fields set to [code]null[/code].
@abstract
extends RefCounted

const AtlasItem = preload("atlas_item.gd")
const VersionInfo = preload("version_info.gd")

# Why a Callable? While the atlas is being freed, a call to one of its own methods fails ("on a null instance"),
# but a call through a Callable still reaches it.
var _unbind_refs_callable: Callable = unbind_refs
## Whether a loader is loading this atlas. [Archmage.AtlasLoader] sets it.
@warning_ignore("unused_private_class_variable")
var _loading := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_unbind_refs_callable.call()


## Returns the items, keyed by their keys in atlas.json, such as [code]"hero"[/code]. Build the dictionary once
## and return the same one on every call; the loader sets the state of each item on it.
@abstract func atlas_items() -> Dictionary[String, AtlasItem]


## Stores [param version], the [code]version[/code] object of atlas.json, or [code]null[/code] when atlas.json has
## none. The generated code keeps it in [code]data_version[/code].
@abstract func set_data_version(version: VersionInfo) -> void


## Resolves the references between config entries, after all items are loaded.
## [br][br]
## Returns an empty string on success. A non-zero ID with no entry in the referenced table is a load failure: return
## a message that locates the reference and includes the table and the ID, such as
## [code]hero[3].weapon: ItemTable: config entry not found for ID 999[/code]. The loader then returns
## [constant ERR_INVALID_DATA].
@abstract func bind_refs() -> String


## Called after [method bind_refs]. The generated code calls [code]extension.on_loaded(self)[/code], the
## user-edited [code]AtlasExtension[/code]. Returns an empty string on success, or a message that makes the loader
## return [constant FAILED] with that message.
@abstract func on_loaded() -> String


## Sets every reference field of the entries to [code]null[/code] and clears every array and dictionary of
## references.
## [br][br]
## The atlas calls it while it is being freed. A call to a method of the atlas fails then, so call only the methods of
## the objects that the atlas holds, such as [code]hero_table._unbind_refs()[/code].
@abstract func unbind_refs() -> void
