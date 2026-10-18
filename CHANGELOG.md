# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.20.1] - 2026-10-18

### Added

- Package: `addons/archmage/README.md`, so that the release zip and the Godot Asset Store package contain it.

## [0.20.0] - 2026-10-18

### Added

- Initial release of the GDScript SDK for Godot 4.6 or later. It is pure GDScript and needs no C#. To install it, copy `addons/archmage` into the project.
- Loader: `AtlasLoader.load_atlas` loads an atlas synchronously. `AtlasOptions` sets variants, a whitelist or blacklist, and layered override sources.
- Loader: `AtlasLoader.load_atlas_async` loads atlas items in parallel on `WorkerThreadPool`. It also works in Web exports without thread support. The `progress` signal and `cancel()` serve a loading screen.
- Loader: A failure returns an `Error` code, and `get_error_message()` returns the message. A JSON value of the wrong type or an invalid value fails the load with `ERR_PARSE_ERROR`.
- Config: Cross-table refs resolve at load time. A ref field holds the config entry it references.
- Value types: `Duration`, `DateTime`, `MinMax`, `WeightedPool`, `Tuple`, `Rgba`, `Vec2`, `Vec3` and `Vec4`.
- I18n: `I18n` manages multi-language text with automatic fallback. `merge_l10n_file` and `merge_l10n_file_async` merge translation files.
- File system: `Archmage.FS` and `FileAccessFS` load from `res://`, `user://` or a custom source.
- Versioning: VCS metadata from `atlas.json` is available on the loaded atlas through `VersionInfo`.
- Editor plugin: Added `addons/archmage_editor`, which shows config ID properties as dropdowns in the Inspector. Mark a property with `@export_custom(CfgIdProp.HINT, CfgIdProp.HERO)`.
