## Items with selection weights, the type of a wtpool field, for drawing an item with a probability proportional to
## its weight.
##
## The total weight must be from 1 to 1,000,000,000 when an item is drawn.
extends RefCounted

const WeightedPool = preload("weighted_pool.gd")
const ParseError = preload("parse_error.gd")

const _MAX_TOTAL_WEIGHT := 1_000_000_000

## The items, of the item type of the field. An item that references a config entry holds the entry.
var items: Array = []
## The weight of each item in [member items]. A weight is not negative.
var weights: Array[int] = []

## The config IDs of [member items] when the items reference config entries, for [method to_json]. The generated
## code resolves them; [method _unbind_refs] sets the items to [code]null[/code] and keeps the IDs.
var _ref_ids: Array = []


## Returns the pool in [param d], a parsed JSON object, converting each item with [code]conv.call(item, e)[/code],
## or [code]null[/code] when [param d] is [code]null[/code]. When [param conv] records an error in [param e], returns
## [code]null[/code]. When [param refs] is true, the converted items are config IDs: they go to [member _ref_ids],
## and [member items] holds [code]null[/code] for each of them until the generated code resolves them.
## [br][br]
## When [param d] is not an object, [code]items[/code] or [code]weights[/code] is not an array, or a weight is not a
## number, the type mismatch is recorded in [param e] (see [method Archmage.ParseError.report_mismatch]). The value
## of the wrong type is then treated as [code]null[/code].
static func from_json(d: Variant, conv: Callable, e: ParseError = null, refs := false) -> WeightedPool:
	if d is not Dictionary:
		if d != null:
			ParseError.report_mismatch(e, "an object", d, "Archmage.WeightedPool")
		return null
	var wp := WeightedPool.new()
	var a: Variant = d.get("items")
	if a is Array:
		for i in a.size():
			wp.items.append(conv.call(a[i], e))
			if e != null and e.failed:
				return e.at(".items[%d]" % i)
	elif a != null:
		ParseError.report_mismatch(e, "an array", a, "Archmage.WeightedPool.items")
	a = d.get("weights")
	if a is Array:
		for w: Variant in a:
			if w is float or w is int:
				wp.weights.append(int(w))
			else:
				if w != null:
					ParseError.report_mismatch(e, "a number", w, "Archmage.WeightedPool.weights")
				wp.weights.append(0)
	elif a != null:
		ParseError.report_mismatch(e, "an array", a, "Archmage.WeightedPool.weights")
	if refs:
		wp._ref_ids = wp.items
		wp.items = []
		wp.items.resize(wp._ref_ids.size())
	return wp


## Returns the pool as a JSON object. An item that references a config entry is written as its config ID.
func to_json() -> Dictionary:
	return {"items": items if _ref_ids.is_empty() else _ref_ids, "weights": weights}


## Returns the number of items.
func size() -> int:
	return items.size()


## Returns a shallow copy of the pool. The copy has its own [member items] and [member weights] arrays, so changing
## them does not change this pool, but the items themselves, such as config entries, are shared.
func duplicate() -> WeightedPool:
	var wp := WeightedPool.new()
	wp.items = items.duplicate()
	wp.weights = weights.duplicate()
	wp._ref_ids = _ref_ids.duplicate()
	return wp


## Returns an item drawn with a probability proportional to its weight, using [param rng], or the global random
## number generator, which [method @GlobalScope.seed] affects, when [param rng] is [code]null[/code]. When the pool is
## empty or the total weight is not from 1 to 1,000,000,000, reports an error and returns [code]null[/code].
func sample(rng: RandomNumberGenerator = null) -> Variant:
	var i := sample_index(rng)
	return null if i < 0 else items[i]


## Returns the index of an item drawn as [method sample] draws it, or [code]-1[/code] when [method sample] reports an
## error.
func sample_index(rng: RandomNumberGenerator = null) -> int:
	var total := _total_weight("sample_index")
	if total <= 0:
		return -1
	var value := rng.randi_range(0, total - 1) if rng != null else randi_range(0, total - 1)
	return _index_at(value)


## Returns the item that [param value] maps to, so that the same value always gives the same item. The values from 0
## to 1 are divided among the items in proportion to their weights. A value below 0 gives the first item with a
## non-zero weight, and a value of 1 or more gives the last. Reports an error and returns [code]null[/code] in the
## same cases as [method sample].
func sample_with(value: float) -> Variant:
	var i := sample_index_with(value)
	return null if i < 0 else items[i]


## Returns the index of the item that [method sample_with] returns, or [code]-1[/code] when it reports an error.
func sample_index_with(value: float) -> int:
	var total := _total_weight("sample_index_with")
	if total <= 0:
		return -1
	return _index_at(int(clampf(value * total, 0, total - 1)))


# Returns the total weight, or 0 after reporting an error when no item can be drawn.
func _total_weight(method: String) -> int:
	if items.is_empty():
		push_error("<archmage> WeightedPool.%s: empty pool" % method)
		return 0
	var total := 0
	for w in weights:
		total += w
	if total == 0:
		push_error("<archmage> WeightedPool.%s: total weight is zero" % method)
		return 0
	if total > _MAX_TOTAL_WEIGHT:
		push_error("<archmage> WeightedPool.%s: total weight exceeds 1,000,000,000" % method)
		return 0
	return total


# Returns the index of the item whose share of the total weight contains position, from 0 to the total weight - 1.
func _index_at(position: int) -> int:
	var acc := 0
	for i in weights.size():
		acc += weights[i]
		if acc > position:
			return i
	return weights.size() - 1


## Sets the items to [code]null[/code] when they reference config entries, or calls [code]_unbind_refs()[/code] of
## the items that are objects of the generated code, so that the entries can be freed. The generated code calls it.
func _unbind_refs() -> void:
	if not _ref_ids.is_empty():
		items.fill(null)
		return
	for e: Variant in items:
		if e is Object and e != null and e.has_method(&"_unbind_refs"):
			e._unbind_refs()
