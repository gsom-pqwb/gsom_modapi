extends GsomModCore

var __peer: LifetimePeer = null

func _get_version() -> StringName:
	return &"test"

func _mod_init() -> void:
	LifetimeObserver.track(self)
	__peer = LifetimePeer.new()
	__peer.owner = self
	LifetimeObserver.track(__peer)
	var description: GsomModContent = GsomModContent.new()
	if LifetimeObserver.use_keys:
		description.key = &"lifetime"
	description.key_weight = 2.0
	LifetimeObserver.track(GsomModapi.register(description))

func _core_main() -> void:
	LifetimeObserver.main_runs += 1
	var runtime_node: Node = Node.new()
	GsomModapi.scene.add_child(runtime_node)
	LifetimeObserver.track(runtime_node)

func _mod_shutdown() -> void:
	LifetimeObserver.events.append(&"core")
	if __peer != null:
		__peer.owner = null
		__peer = null
