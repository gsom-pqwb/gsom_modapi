extends RefCounted
class_name GsomModMeta

## Stop owned work and disconnect external callbacks before this mod is released.
## Implementations must break their own strong-reference cycles here.
## Also called on launch rollback before _mod_init(), so tolerate partial initialization.
func _mod_shutdown() -> void:
	pass

## Redefine this in subclasses
func _mod_init() -> void:
	assert(false, "Not implemented")

## Redefine this in subclasses
func _get_version() -> StringName:
	assert(false, "Not implemented")
	return &"0"
