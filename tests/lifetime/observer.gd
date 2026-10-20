extends Node

var references: Array[WeakRef] = []
var events: Array[StringName] = []
var main_runs: int = 0
var use_keys: bool = true

func track(instance: Object) -> void:
	references.append(weakref(instance))

func retained_count() -> int:
	var result: int = 0
	for reference: WeakRef in references:
		if reference.get_ref() != null:
			result += 1
	return result
