extends RefCounted
class_name GsomModContext

signal stopped()

enum State { STARTING, RUNNING, STOPPING, STOPPED }

var state: State = State.STARTING
var registry: GsomModRegistry = GsomModRegistry.new()
var loader: GsomModLoader = GsomModLoader.new()
var core: GsomModCore = null
var scene: Node = null

func begin_shutdown() -> void:
	state = State.STOPPING
	if core != null:
		core._mod_shutdown()
	loader.stop_mods()

func finish_shutdown() -> void:
	if state == State.STOPPED:
		return
	registry.clear()
	loader.clear()
	core = null
	scene = null
	state = State.STOPPED
	stopped.emit()
