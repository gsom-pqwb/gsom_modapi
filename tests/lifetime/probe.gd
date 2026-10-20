extends Node

var __failures: int = 0
var __peak_retained: int = 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	if not condition:
		__failures += 1
		push_error(description)

func _run() -> void:
	_check_registry_queries()
	_check_selectors()
	_check(GsomModapi.launch("", "res://missing_core.gd") == ERR_FILE_NOT_FOUND, "Missing core must fail")
	_check(GsomModapi.get_context() == null, "Failed launch must not retain a context")
	_check(GsomModapi.launch("", "res://tests/lifetime/invalid_core.gd") == ERR_INVALID_DATA, "Wrong core type must fail")
	_check(GsomModapi.get_context() == null, "Wrong core must not create a context")
	# The runner copies this suite into a disposable writable project.
	_check(DirAccess.make_dir_recursive_absolute("res://mods/broken_lifetime_probe") == OK, "Create invalid mod fixture")
	var broken_mod: FileAccess = FileAccess.open("res://mods/broken_lifetime_probe/mod.gd", FileAccess.WRITE)
	broken_mod.store_string("extends RefCounted\n")
	broken_mod.close()
	_check(GsomModapi.launch("", "res://tests/lifetime/probe_core.gd") == ERR_INVALID_DATA, "Wrong mod type must roll back launch")
	_check(GsomModapi.get_context() == null, "Failed mod load must release context")
	_check(DirAccess.remove_absolute("res://mods/broken_lifetime_probe/mod.gd") == OK, "Remove invalid mod file")
	_check(DirAccess.remove_absolute("res://mods/broken_lifetime_probe") == OK, "Remove invalid mod directory")
	await get_tree().process_frame
	await GsomModapi.shutdown()
	for cycle: int in range(50):
		await _cycle(cycle)
	# A stopped context must not run a deferred core entry point in a later session.
	var runs_before: int = LifetimeObserver.main_runs
	_check(GsomModapi.launch("", "res://tests/lifetime/probe_core.gd") == OK, "Launch before immediate stop")
	GsomModapi.shutdown.call_deferred()
	await GsomModapi.shutdown()
	await get_tree().process_frame
	_check(LifetimeObserver.main_runs == runs_before, "Stopped deferred core must not run")
	_check(LifetimeObserver.retained_count() == 0, "Immediate stop must release instances")
	await GsomModapi.shutdown()
	print("LIFETIME cycles=50 peak_retained_after_shutdown=", __peak_retained, " failures=", __failures)
	get_tree().quit(0 if __failures == 0 else 1)

func _check_registry_queries() -> void:
	var registry: GsomModRegistry = GsomModRegistry.new()
	var lower: GsomModContent = GsomModContent.new()
	lower.add_attrs({&"rank": 1.0})
	var higher: GsomModContent = GsomModContent.new()
	higher.add_attrs({&"rank": 2.0})
	registry.register(lower, &"test:1", &"test")
	registry.register(higher, &"test:2", &"test")
	_check(lower.id.is_empty() and higher.id.is_empty(), "Registration must not mutate source resources")
	var filter: GsomModQueryFilter = GsomModQueryFilter.new()
	filter.sort_attr = &"rank"
	var filtered: Array[GsomModContent] = registry.get_by_query(filter)
	_check(filtered.size() == 2 and filtered[0].id == &"test:2", "Filter must sort by attribute")
	var pick: GsomModQueryPick = GsomModQueryPick.new()
	pick.pick_ids = [&"test:1", &"test:2"]
	pick.sort_attr = &"rank"
	var picked: Array[GsomModContent] = registry.get_by_query(pick)
	_check(picked.size() == 2 and picked[0].id == &"test:2", "Pick must sort by attribute")
	filtered.clear()
	picked.clear()
	registry.clear()
	_check(registry.get_by_mod(&"test").is_empty() and registry.get_by_id(&"test:1") == null, "Clear must reset every index")

func _check_selectors() -> void:
	var parent: GsomModSelector = GsomModSelector.new()
	var child: GsomModSelector = GsomModSelector.new()
	var query: GsomModQueryPick = GsomModQueryPick.new()
	child.table[query] = 2.0
	parent.selectors.append(child)
	child.selectors.append(parent)
	var combined: Dictionary[GsomModQueryBase, float] = parent.get_raw()
	_check(combined.size() == 1 and combined[query] == 2.0, "Consumer-typed selector traversal must handle cyclic input")
	_check(parent.get_normalized()[query] == 1.0, "Selector normalization must be preserved")
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 1
	_check(parent.pick_one_query(random) == query, "Selector must return the typed query")
	# Traversal guards stop recursion; owners must still break actual Resource cycles.
	parent.selectors.clear()
	child.selectors.clear()

func _cycle(cycle: int) -> void:
	LifetimeObserver.events.clear()
	_check(GsomModapi.launch("", "res://tests/lifetime/probe_core.gd") == OK, "Launch failed")
	_check(GsomModapi.launch("", "res://tests/lifetime/probe_core.gd") == ERR_ALREADY_IN_USE, "Repeated launch must reject active context")
	await get_tree().process_frame
	var context: GsomModContext = GsomModapi.get_context()
	LifetimeObserver.track(context)
	LifetimeObserver.track(context.registry)
	LifetimeObserver.track(context.loader)
	LifetimeObserver.track(GsomModapi.scene)
	_check(GsomModapi.scene.get_child_count() == 1, "New context must have exactly one runtime node")
	var descriptions: Array[GsomModContent] = GsomModapi.content_by_key_all(&"lifetime")
	_check(descriptions.size() == 2, "Both descriptions must be indexed exactly once")
	_check(GsomModapi.content_by_kind(&"unknown").size() == 1, "Key resolution must select a single winner")
	_check(GsomModapi.content_by_key(&"lifetime").key_weight == 2.0, "Core override must win")
	_check(GsomModapi.content_by_id(&"missing") == null, "Missing ID must return null")
	var query: GsomModQueryPick = GsomModQueryPick.new()
	query.pick_keys = [&"lifetime"]
	_check(GsomModapi.content_by_query(query).size() == 1, "Queries must resolve the current context")
	# Query result arrays belong to callers and cannot mutate registry indexes.
	descriptions.clear()
	_check(GsomModapi.content_by_key_all(&"lifetime").size() == 2, "Query results must not expose internal arrays")
	descriptions = []
	query = null
	context = null
	await GsomModapi.shutdown()
	await get_tree().process_frame
	_check(GsomModapi.get_context() == null and GsomModapi.scene == null, "Context must detach after shutdown")
	_check(GsomModapi.content_by_kind(&"unknown").is_empty(), "Stopped registry must be empty")
	_check(LifetimeObserver.events == [&"core", &"mod"], "Shutdown hooks must run once in reverse dependency order")
	var retained: int = LifetimeObserver.retained_count()
	__peak_retained = maxi(__peak_retained, retained)
	_check(retained == 0, "Instances retained after cycle %d: %d" % [cycle + 1, retained])
	if cycle == 0 or cycle == 49:
		print("AFTER cycle=", cycle + 1, " registry_entries=", GsomModapi.content_by_kind(&"unknown").size(), " retained_instances=", retained)
