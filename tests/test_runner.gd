## Runs every test method one by one on the main thread, writes a summary and quits.
##
## Test scripts are the files named [code]*_test.gd[/code] under [code]res://tests[/code]; they extend
## [code]res://tests/test_case.gd[/code]. The runner creates a new instance of the script for each method
## named [code]test_*[/code] and awaits the method.
##
## From the project directory, pass the scene as the scene to run:
## [code]godot --headless --path . res://tests/test_runner.tscn -- [--filter <regex>] [--summary <file>][/code].
## The release template does not accept a scene path, so the export preset "macOS (tests)" makes this the main scene;
## pass only the arguments after [code]--[/code]. The filter is matched against [code]script.method[/code],
## such as [code]archmage_test.test_version[/code]. The exit code is 0 when all tests pass and at least one test ran,
## and 1 otherwise.
extends Node

const TESTS_DIR := "res://tests"
## Directories under [constant TESTS_DIR] that hold data, not test scripts.
const DATA_DIRS := ["testdata", "override", "golden"]
const TEST_CASE = preload("test_case.gd")


## Receives every error that the engine or a script logs. While a test runs, it fails that test, or records the
## error when the test is capturing errors. It can be called from any thread.
class ErrorLogger extends Logger:
	var current = null
	var _mutex := Mutex.new()

	func set_current(test) -> void:
		_mutex.lock()
		current = test
		_mutex.unlock()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if rationale != "" else code
		var message := "error: %s (%s:%d, %s)" % [text, file, line, function]
		_mutex.lock()
		if current != null:
			if current.capturing:
				current.captured.append(message)
			else:
				current.failures.append(message)
		_mutex.unlock()


func _ready() -> void:
	var exit_code := 1
	var summary := ""
	var summary_file := ""
	var filter: RegEx = null

	var args := OS.get_cmdline_user_args()
	var i := 0
	var bad_args := false
	var error_logger := ErrorLogger.new()
	OS.add_logger(error_logger)
	while i < args.size():
		if args[i] == "--filter" and i + 1 < args.size():
			i += 1
			filter = RegEx.create_from_string(args[i])
			if filter == null:
				push_error("[TestRunner] Invalid --filter: %s" % args[i])
				bad_args = true
		elif args[i] == "--summary" and i + 1 < args.size():
			i += 1
			summary_file = args[i]
		else:
			push_error("[TestRunner] Unknown argument: %s" % args[i])
			bad_args = true
		i += 1

	if not bad_args:
		var results: Array[Dictionary] = []
		for path in _find_scripts(TESTS_DIR):
			var script := load(path) as GDScript
			if script == null:
				results.append({"name": path.get_file(), "ok": false, "ms": 0, "message": "cannot load the script"})
				continue
			for method in _test_methods(script):
				var test_name := "%s.%s" % [path.get_file().get_basename(), method]
				if filter != null and filter.search(test_name) == null:
					continue
				print("[TestRunner] ", test_name)
				results.append(await _run_test(test_name, script, method, error_logger))
		summary = _summarize(results)
		print(summary)
		var passed := results.size() > 0 and results.all(func(r): return r.ok)
		exit_code = 0 if passed else 1
		if summary_file != "":
			var f := FileAccess.open(summary_file, FileAccess.WRITE)
			if f == null:
				push_error("[TestRunner] Cannot write %s" % summary_file)
				exit_code = 1
			else:
				f.store_string(summary)
				f.close()
	OS.remove_logger(error_logger)
	get_tree().quit(exit_code)


func _run_test(test_name: String, script: GDScript, method: String, error_logger: ErrorLogger) -> Dictionary:
	var start := Time.get_ticks_msec()
	var instance = script.new()
	if not (instance is TEST_CASE):
		return {"name": test_name, "ok": false, "ms": 0, "message": "the script does not extend test_case.gd"}
	error_logger.set_current(instance)
	await instance.call(method)
	error_logger.set_current(null)
	var failures: Array[String] = instance.failures
	return {
		"name": test_name,
		"ok": failures.is_empty(),
		"ms": Time.get_ticks_msec() - start,
		"message": "\n".join(failures),
	}


func _summarize(results: Array[Dictionary]) -> String:
	var lines: PackedStringArray = []
	var failed := 0
	for r in results:
		if not r.ok:
			failed += 1
			lines.append("FAILED %s (%d ms)\n%s" % [r.name, r.ms, r.message])
	lines.append("Total: %d, passed: %d, failed: %d" % [results.size(), results.size() - failed, failed])
	if results.is_empty():
		lines.append("No test ran.")
	return "\n".join(lines) + "\n"


func _test_methods(script: GDScript) -> Array[String]:
	var names: Array[String] = []
	for m in script.get_script_method_list():
		if m.name.begins_with("test_") and not names.has(m.name):
			names.append(m.name)
	names.sort()
	return names


## Returns the paths of the test scripts under [param dir], sorted. The directory is listed, not a fixed list
## of scripts, so a new test file needs no registration. In an exported program, the listing shows a script as
## [code]x.gd.remap[/code] or [code]x.gdc[/code]; both map back to [code]x.gd[/code], which [code]load[/code]
## resolves.
func _find_scripts(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".gdc") or name.ends_with(".gde"):
			name = name.get_basename() + ".gd"
		if name.ends_with("_test.gd") and not found.has(dir + "/" + name):
			found.append(dir + "/" + name)
	for sub in DirAccess.get_directories_at(dir):
		if dir == TESTS_DIR and DATA_DIRS.has(sub):
			continue
		found.append_array(_find_scripts(dir + "/" + sub))
	found.sort()
	return found
