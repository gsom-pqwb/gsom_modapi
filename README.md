# gsom_modapi

A generic content-based mod framework for Godot 4.
- The main idea is to represent 99% of the game implementation as "mod content".

There is a singleton `GsomModapi`, and several helper classes, which let you
define content entries, and then find/list and spawn them later.
This approach is being scaled from tiniest items or visual effects to whole
gameplay modes and systems.

## GsomModapi

### Explicit context lifetime

`launch(core_pck, core_script) -> Error` creates one `GsomModContext` owning the mod instances, core, registry, and runtime root node exposed as `scene`. Calling `launch` while a context is active or stopping returns `ERR_ALREADY_IN_USE`. Await shutdown before launching again:

```gdscript
var result: Error = GsomModapi.launch("", "res://core/core.gd")
if result != OK:
	push_error(error_string(result))
	return

# Later, from the controlling node:
await GsomModapi.shutdown()
```

`shutdown()` invokes `_mod_shutdown()` on the core, then on mods in reverse load order, queues the runtime scene for deletion, and waits for a scene-tree frame. It then clears the registry, loader, and core references. Repeated and concurrent shutdown requests are safe. During scene-tree exit, references are released without waiting for another frame; Godot's tree frees the child nodes.

`_mod_shutdown() -> void` is a new optional synchronous hook in `GsomModMeta`. It must stop owned work, disconnect external callbacks, and break owned strong-reference cycles. The hook is also called when a partially prepared launch is rolled back, so implementations must tolerate incomplete initialization. Arbitrary user resource graphs are not automatically traversed or destroyed. Neither `_mod_init()` nor `_mod_shutdown()` may suspend with `await`; initialization hooks must not change the active context's lifecycle.

The registry and loader now belong to a context instead of keeping mutable static state. Only the ID index owns content descriptions; secondary indexes store IDs. Queries return separate result arrays. Registration is available during mod/core initialization and does not mutate the source resource. `scene` is `null` outside a context. Direct calls to the former static helpers are no longer supported; the public query methods on `GsomModapi` are preserved.

Content descriptions and spawned game objects have different lifetimes. An external strong reference will keep a description alive after `shutdown()`; consumers must release it when the data is no longer needed. Asynchronous work should capture its context and check that context's state before continuing, so a stale callback cannot operate on a new global context.

Loading a PCK changes Godot's process-wide resource space. This implementation does not unmount packages or guarantee hot replacement of files. Verification used Godot 4.7.2; compatibility with the Godot 4.5.1 version originally listed in CONTRIBUTING has not been rechecked.

### Self-referential containers

`GsomModSelector.selectors` uses `Array[Resource]` to avoid a reference to its own script type in a persistent default field value. Traversal checks each entry with `is GsomModSelector` before using a local variable of that concrete type. Invalid or null entries report an error; partial results are not cached. The inspector accepts the base Resource type, so the exact contract is validated by the consumer.

On Godot 4.7.2, this change removed the remaining two script-resource diagnostics. Separate probes verified an untyped `Array` field with a concrete local variable, an `Array[Resource]` field with the same local type, and a local `Array[OwnClass]`: all exited without retained script resources. Changing a field's element type does not break actual object cycles stored in the array; their owner must still break them.

Measurements and reproducible scenarios are documented in [tests/lifetime/README.md](tests/lifetime/README.md).
