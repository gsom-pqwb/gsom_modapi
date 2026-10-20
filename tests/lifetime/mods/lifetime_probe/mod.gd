extends GsomModMeta

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
	description.key_weight = 1.0
	LifetimeObserver.track(GsomModapi.register(description))

func _mod_shutdown() -> void:
	LifetimeObserver.events.append(&"mod")
	if __peer != null:
		__peer.owner = null
		__peer = null
