extends Node

const ModDeps: GDScript = preload("./helpers/mod_deps.gd")

var __context: GsomModContext = null

## Runtime nodes belong to this context's scene tree, not the content registry.
var scene: Node:
	get:
		return __context.scene if __context != null else null

func get_context() -> GsomModContext:
	return __context

func launch(core_pck: String, core_script: String) -> Error:
	if __context != null:
		return ERR_ALREADY_IN_USE
	if not core_pck.is_empty() and not ProjectSettings.load_resource_pack(core_pck, false):
		return ERR_FILE_CANT_OPEN
	if not ResourceLoader.exists(core_script, "GDScript"):
		return ERR_FILE_NOT_FOUND
	var script: GDScript = load(core_script) as GDScript
	if script == null or not script.can_instantiate():
		return ERR_INVALID_DATA
	var instance: Variant = script.new()
	if not instance is GsomModCore:
		if instance is Object and not instance is RefCounted:
			instance.free()
		return ERR_INVALID_DATA
	var context: GsomModContext = GsomModContext.new()
	context.core = instance
	context.scene = Node.new()
	context.scene.name = "ModContext"
	__context = context
	add_child(context.scene)
	var load_result: Error = context.loader.load_mods()
	if load_result != OK:
		context.begin_shutdown()
		context.scene.queue_free()
		__context = null
		context.finish_shutdown()
		return load_result
	context.loader.start_phase(&"~")
	context.core._mod_init()
	context.loader.end_phase()
	context.state = GsomModContext.State.RUNNING
	__start_core.call_deferred(context)
	return OK

func __start_core(context: GsomModContext) -> void:
	if __context == context and context.state == GsomModContext.State.RUNNING:
		context.core._core_main()

## Await shutdown before relaunching. Repeated/concurrent shutdown is safe.
func shutdown() -> void:
	var context: GsomModContext = __context
	if context == null:
		return
	if context.state == GsomModContext.State.STARTING:
		push_error("Await shutdown after launch has returned, not from an initialization hook")
		return
	if context.state == GsomModContext.State.STOPPING:
		await context.stopped
		return
	context.begin_shutdown()
	context.scene.queue_free()
	await get_tree().process_frame
	if __context == context:
		__context = null
	context.finish_shutdown()

func _exit_tree() -> void:
	if __context != null:
		if __context.state != GsomModContext.State.STOPPING:
			__context.begin_shutdown()
		var context: GsomModContext = __context
		__context = null
		context.finish_shutdown()

func register(description: GsomModContent) -> GsomModContent:
	if __context == null or __context.state != GsomModContext.State.STARTING:
		push_error("Content registration is only available during mod initialization")
		return null
	return __context.registry.register(description, __context.loader.gen_id(), __context.loader.get_phase())

func content_by_id(content_id: StringName) -> GsomModContent:
	return __context.registry.get_by_id(content_id) if __context != null else null

func content_by_kind(kind: StringName) -> Array[GsomModContent]:
	return __context.registry.get_by_kind(kind) if __context != null else []

func content_by_key(key: StringName) -> GsomModContent:
	return __context.registry.get_by_key(key) if __context != null else null

func content_by_key_all(key: StringName) -> Array[GsomModContent]:
	return __context.registry.get_by_key_all(key) if __context != null else []

func content_by_query(query: GsomModQueryBase) -> Array[GsomModContent]:
	return __context.registry.get_by_query(query) if __context != null else []

func content_by_mod(mod_name: StringName) -> Array[GsomModContent]:
	return __context.registry.get_by_mod(mod_name) if __context != null else []

func traverse_selector(selector: GsomModSelector) -> Array[StringName]:
	return ModDeps.traverse_selector(selector, __context.registry) if __context != null else []

func traverse_query(query: GsomModQueryBase) -> Array[StringName]:
	return ModDeps.traverse_query(query, __context.registry) if __context != null else []

func traverse_content(content: GsomModContent) -> Array[StringName]:
	return ModDeps.traverse_content(content, __context.registry) if __context != null else []
