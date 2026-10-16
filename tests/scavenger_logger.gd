## A logger for tests that keeps every message.
extends Archmage.AtlasLogger

var lines: Array[String] = []


func info(message: String) -> void:
	lines.append(message)
