extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	LifetimeObserver.use_keys = false
	for cycle: int in range(50):
		GsomModapi.launch("", "res://tests/lifetime/probe_core.gd")
		await get_tree().process_frame
		if cycle == 0 or cycle == 49:
			print("COMPARE_BEFORE cycle=", cycle + 1, " entries=", GsomModapi.content_by_kind(&"unknown").size(), " nodes=", GsomModapi.scene.get_child_count())
	print("COMPARE_BEFORE retained=", LifetimeObserver.retained_count(), " tracked=", LifetimeObserver.references.size())
	get_tree().quit()
