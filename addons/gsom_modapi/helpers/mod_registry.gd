extends RefCounted
class_name GsomModRegistry

const ModFilters: GDScript = preload("./mod_filters.gd")

class ContentIds:
	extends RefCounted
	var values: Array[StringName] = []

var __by_id: Dictionary[StringName, GsomModContent] = {}
var __by_kind: Dictionary[StringName, ContentIds] = {}
var __by_mod: Dictionary[StringName, ContentIds] = {}
var __by_key: Dictionary[StringName, ContentIds] = {}

func register(source: GsomModContent, content_id: StringName, mod_name: StringName) -> GsomModContent:
	if content_id.is_empty() or source == null:
		push_error("Content registration requires a description and an initialization phase")
		return null
	if __by_id.has(content_id):
		push_error("Duplicate content ID: " + String(content_id))
		return null
	var description: GsomModContent = source.duplicate_deep() as GsomModContent
	description.id = content_id
	description.mod = mod_name
	__by_id[content_id] = description
	__append(__by_kind, description.kind, content_id)
	__append(__by_mod, mod_name, content_id)
	if not description.key.is_empty():
		__append(__by_key, description.key, content_id)
		__by_key[description.key].values.sort_custom(__key_precedes)
	return description

func clear() -> void:
	__by_kind.clear()
	__by_mod.clear()
	__by_key.clear()
	__by_id.clear()

func get_by_id(content_id: StringName) -> GsomModContent:
	var description: GsomModContent = __by_id.get(content_id)
	if description == null or description.key.is_empty():
		return description
	return get_by_key(description.key)

func get_by_kind(kind: StringName) -> Array[GsomModContent]:
	return __filter_keyed_content(__resolve(__by_kind.get(kind)))

func get_by_mod(mod_name: StringName) -> Array[GsomModContent]:
	return __filter_keyed_content(__resolve(__by_mod.get(mod_name)))

func get_by_key(key: StringName) -> GsomModContent:
	var ids: ContentIds = __by_key.get(key)
	return __by_id[ids.values[0]] if ids != null and not ids.values.is_empty() else null

func get_by_key_all(key: StringName) -> Array[GsomModContent]:
	return __resolve(__by_key.get(key))

func get_by_query(query: GsomModQueryBase) -> Array[GsomModContent]:
	if query is GsomModQueryFilter:
		return __filter_by_query(query)
	if query is GsomModQueryPick:
		return __pick_by_query(query)
	push_error("Unsupported query type")
	return []

func __append(index: Dictionary[StringName, ContentIds], key: StringName, content_id: StringName) -> void:
	if not index.has(key):
		index[key] = ContentIds.new()
	index[key].values.append(content_id)

func __resolve(ids: ContentIds) -> Array[GsomModContent]:
	var result: Array[GsomModContent] = []
	if ids != null:
		for content_id: StringName in ids.values:
			result.append(__by_id[content_id])
	return result

func __key_precedes(first_id: StringName, second_id: StringName) -> bool:
	return __by_id[first_id].key_weight > __by_id[second_id].key_weight

func __filter_keyed_content(items: Array[GsomModContent]) -> Array[GsomModContent]:
	var result: Array[GsomModContent] = []
	for description: GsomModContent in items:
		if description.key.is_empty() or get_by_key(description.key) == description:
			result.append(description)
	return result

func __filter_by_query(query: GsomModQueryFilter) -> Array[GsomModContent]:
	var result: Array[GsomModContent] = []
	for description: GsomModContent in __by_id.values():
		if (ModFilters.passes_kind(description, query) and ModFilters.passes_caps(description, query)
			and ModFilters.passes_tags(description, query) and ModFilters.passes_attrs(description, query)):
			result.append(description)
	if result.size() > 1 and not query.sort_attr.is_empty():
		result.sort_custom(__attribute_precedes.bind(query.sort_attr))
	return __filter_keyed_content(result)

func __pick_by_query(query: GsomModQueryPick) -> Array[GsomModContent]:
	var result: Array[GsomModContent] = []
	for content_id: StringName in query.pick_ids:
		var description: GsomModContent = get_by_id(content_id)
		if description != null and not result.has(description):
			result.append(description)
	for key: StringName in query.pick_keys:
		var description: GsomModContent = get_by_key(key)
		if description != null and not result.has(description):
			result.append(description)
	if result.size() > 1 and not query.sort_attr.is_empty():
		result.sort_custom(__attribute_precedes.bind(query.sort_attr))
	return result

func __attribute_precedes(first: GsomModContent, second: GsomModContent, attribute: StringName) -> bool:
	return ModFilters.sort_by_attr(attribute, first, second)
