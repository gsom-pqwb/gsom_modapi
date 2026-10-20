extends RefCounted


static func traverse_selector(
	selector: GsomModSelector,
	registry: GsomModRegistry,
	visited: Dictionary[StringName, bool] = {},
) -> Array[StringName]:
	var result: Array[StringName] = []
	for query: GsomModQueryBase in selector.table.keys():
		result.append_array(traverse_query(query, registry, visited))
	return result

static func traverse_query(
	query: GsomModQueryBase,
	registry: GsomModRegistry,
	visited: Dictionary[StringName, bool] = {},
) -> Array[StringName]:
	var result: Array[StringName] = []
	for content: GsomModContent in registry.get_by_query(query):
		if visited.has(content.id):
			continue
		visited[content.id] = true
		result.append_array(traverse_content(content, registry, visited))
	return result

static func traverse_content(
	content: GsomModContent,
	registry: GsomModRegistry,
	visited: Dictionary[StringName, bool] = {},
) -> Array[StringName]:
	var result: Array[StringName] = []
	
	result.append_array(content.list_paths())

	if content.dep_query:
		result.append_array(traverse_query(content.dep_query, registry, visited))

	if content.dep_queries:
		for query: GsomModQueryBase in content.dep_queries:
			result.append_array(traverse_query(query, registry, visited))

	if content.dep_selector:
		result.append_array(traverse_selector(content.dep_selector, registry, visited))
	
	return result
