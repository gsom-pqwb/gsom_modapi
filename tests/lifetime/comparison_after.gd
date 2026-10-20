extends Node

var __failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	LifetimeObserver.use_keys = false
	for cycle: int in range(50):
		if GsomModapi.launch("", "res://tests/lifetime/probe_core.gd") != OK:
			__failures += 1
		await get_tree().process_frame
		if cycle == 0 or cycle == 49:
			print("COMPARE_AFTER active_cycle=", cycle + 1, " entries=", GsomModapi.content_by_kind(&"unknown").size(), " nodes=", GsomModapi.scene.get_child_count())
		await GsomModapi.shutdown()
		await get_tree().process_frame
		if LifetimeObserver.retained_count() != 0:
			__failures += 1
	print("COMPARE_AFTER retained=", LifetimeObserver.retained_count(), " tracked=", LifetimeObserver.references.size(), " entries=", GsomModapi.content_by_kind(&"unknown").size(), " failures=", __failures)
	get_tree().quit(0 if __failures == 0 else 1)
