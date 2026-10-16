## Receives the progress messages of the loader, such as the items loaded and skipped.
##
## The default logger prints each message with [method @GlobalScope.print], after [code]INF [/code], as the C# SDK
## does. Extend this class and override [method info] to send them elsewhere; [Archmage.NullLogger] discards them.
extends RefCounted


## Receives one message, such as [code]<archmage> Loaded 9 atlas items in 12ms[/code].
func info(message: String) -> void:
	print("INF " + message)
