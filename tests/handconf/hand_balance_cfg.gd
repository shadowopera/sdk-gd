## The balance config (property sheet, variant-mapped). A subset of the fields of testdata/balance.*.json.
class_name HandBalanceCfg
extends RefCounted

const J = preload("hand_json.gd")

var hp_scale: float
var dmg_scale: float
var gold_bonus: float
var enemy_level: int
var xp_curve: Array[int] = []


func load_json(d: Variant) -> void:
	if d == null:
		d = {}
	hp_scale = J.f(d.get("hpScale"))
	dmg_scale = J.f(d.get("dmgScale"))
	gold_bonus = J.f(d.get("goldBonus"))
	enemy_level = J.i(d.get("enemyLevel"))
	xp_curve.clear()
	var a: Variant = d.get("xpCurve")
	if a != null:
		for e: Variant in a:
			xp_curve.append(J.i(e))


func to_json() -> Dictionary:
	return {"hpScale": hp_scale, "dmgScale": dmg_scale, "goldBonus": gold_bonus, "enemyLevel": enemy_level, "xpCurve": xp_curve}
