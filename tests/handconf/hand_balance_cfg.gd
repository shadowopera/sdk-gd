## The balance config (property sheet, variant-mapped). A subset of the fields of testdata/balance.*.json.
class_name HandBalanceCfg
extends RefCounted

const J = preload("hand_json.gd")

var hp_scale: float
var dmg_scale: float
var gold_bonus: float
var enemy_level: int
var xp_curve: Array[int] = []


func load_json(d: Variant) -> String:
	var pe := Archmage.ParseError.new()
	d = J.m(d, pe)
	hp_scale = J.f(d.get("hpScale"), pe)
	dmg_scale = J.f(d.get("dmgScale"), pe)
	gold_bonus = J.f(d.get("goldBonus"), pe)
	enemy_level = J.i(d.get("enemyLevel"), pe)
	xp_curve.clear()
	for e: Variant in J.a(d.get("xpCurve"), pe):
		xp_curve.append(J.i(e, pe))
	if pe.mismatched:
		return pe.message_at("")
	return ""


func to_json() -> Dictionary:
	return {"hpScale": hp_scale, "dmgScale": dmg_scale, "goldBonus": gold_bonus, "enemyLevel": enemy_level, "xpCurve": xp_curve}
