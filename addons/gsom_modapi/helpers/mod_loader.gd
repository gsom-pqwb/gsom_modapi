extends RefCounted
class_name GsomModLoader

class ModSettings:
	var disabled_mods: Array[StringName] = []

var __mod_settings: ModSettings = null
var __phase: StringName = &""
var __id: int = 0

var loaded_mods: Dictionary[StringName, GsomModMeta] = {}

func stop_mods() -> void:
	var names: Array[StringName] = loaded_mods.keys()
	names.reverse()
	for name: StringName in names:
		loaded_mods[name]._mod_shutdown()

func clear() -> void:
	loaded_mods.clear()
	__mod_settings = null
	end_phase()

func load_mods() -> Error:
	__read_settings()
	
	var user_mod_names: PackedStringArray = __fetch_user_mod_names()
	var builtin_mod_names: PackedStringArray = __fetch_builtin_mod_names()
	
	var loaded_mod_names: PackedStringArray = []
	for name: String in user_mod_names:
		if __mod_settings.disabled_mods.has(name):
			continue
		if ProjectSettings.load_resource_pack("user://mods/%s.pck" % name, false):
			loaded_mod_names.append(name)
	
	for name: String in builtin_mod_names:
		if !loaded_mod_names.has(name):
			loaded_mod_names.append(name)
	loaded_mod_names.sort()
	
	for name: String in loaded_mod_names:
		var script_path: String = "res://mods/%s/mod.gd" % name
		if not ResourceLoader.exists(script_path, "GDScript"):
			return ERR_FILE_NOT_FOUND
		var script: GDScript = load(script_path) as GDScript
		if script == null or not script.can_instantiate():
			return ERR_INVALID_DATA
		var instance: Variant = script.new()
		if not instance is GsomModMeta:
			if instance is Object and not instance is RefCounted:
				instance.free()
			return ERR_INVALID_DATA
		loaded_mods[name] = instance
	
	for name: StringName in loaded_mods:
		start_phase(name)
		loaded_mods[name]._mod_init()
		end_phase()
	return OK

# Reads "user://mods/*" for external mods.
# @returns An array of directory names found under "mods".
func __fetch_user_mod_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var base: String = "user://mods"

	if not DirAccess.dir_exists_absolute(base):
		return result

	var dir: DirAccess = DirAccess.open(base)
	if dir == null:
		return result

	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break

		# Skip files and special entries
		if name == "." or name == "..":
			continue
		if dir.current_is_dir():
			result.append(name)

	dir.list_dir_end()
	return result


# Reads "res://mods/*" for builtin mods.
# @returns An array of directory names found under "mods".
func __fetch_builtin_mod_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var base: String = "res://mods"

	# res:// may not contain a mods folder
	if not DirAccess.dir_exists_absolute(base):
		return result

	var dir: DirAccess = DirAccess.open(base)
	if dir == null:
		return result

	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break

		# Skip files and special entries
		if name == "." or name == "..":
			continue
		if dir.current_is_dir():
			result.append(name)

	dir.list_dir_end()
	return result

# Reads "user://mod_settings.json" if it exists
#
# Only the fields present in `__mod_settings_default` are taken.
# Only if they match the data type - array to array, object to object, number to number, etc.
#
# The missing fields are taken from `__mod_settings_default` as is.
func __read_settings() -> void:
	__mod_settings = ModSettings.new()

# Writes "user://mod_settings.json"
# The `__mod_settings` var contents is dumped into the file
func __write_settings() -> void:
	pass

# Per-mod loading phase
func start_phase(name: StringName) -> void:
	__phase = name
	__id = 0

# Create a pre-mod ID
func gen_id() -> StringName:
	if !__phase:
		push_error("Can't generate ID outside init phases.")
		return &""
	__id += 1
	return &"%s:%s" % [__phase, __id]

# Finish the load phase
func end_phase() -> void:
	__phase = &""
	__id = 0

# Mod name currently being loaded
func get_phase() -> StringName:
	return __phase
