extends Node

func _ready() -> void:
	var selector: GsomModSelector = GsomModSelector.new()
	var query: GsomModQueryPick = GsomModQueryPick.new()
	selector.table[query] = 1.0
	selector.selectors.append(Resource.new())
	if not selector.get_raw().is_empty():
		get_tree().quit(1)
		return
	selector.selectors.clear()
	selector.selectors.append(null)
	if not selector.get_raw().is_empty():
		get_tree().quit(1)
		return
	selector.selectors.clear()
	var child: GsomModSelector = GsomModSelector.new()
	child.table[query] = 2.0
	selector.selectors.append(child)
	var combined: Dictionary[GsomModQueryBase, float] = selector.get_raw()
	if combined.size() != 1 or combined[query] != 3.0:
		get_tree().quit(1)
		return
	print("INVALID_SELECTOR validated=2 recovered=true")
	get_tree().quit()
