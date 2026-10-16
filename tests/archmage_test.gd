extends "res://tests/test_case.gd"


func test_version() -> void:
	check(Archmage.VERSION != "", "Archmage.VERSION is empty")
