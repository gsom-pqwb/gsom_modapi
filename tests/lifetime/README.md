# ModAPI lifetime verification

Date: 2026-10-20 (UTC). Godot `4.7.2.stable.official.ed1daf0bf`, Windows x64. Run from the Archbox repository root:

```sh
python addons/gsom_modapi/tests/lifetime/run.py --godot-wrapper tools/godot.sh --output build/addons/gsom_modapi/lifetime-test
```

The `--output` path must not already exist: the runner does not remove or overwrite existing directories. It copies the addon core and fixtures into an isolated project without demo assets, then imports and runs that project. Import and runtime logs are written next to the output directory. In suite/after mode, any ERROR or WARNING fails verification. The before mode preserves baseline diagnostics as measurements; invalid-selector mode requires exactly two expected validation errors and no other errors or warnings.

The suite checks 50 `launch -> await shutdown` cycles, an empty registry after shutdown, and release of contexts, loaders, registries, core instances, mods, descriptions, and runtime nodes through `WeakRef`. The core and mod deliberately form cycles with helper objects; their shutdown hooks break those cycles. The external observer keeps only weak references. Other checks cover registry indexes and sorting, immutable source resources, result arrays that do not expose internal storage, rejection of repeated launches, missing/invalid cores, rollback after an invalid mod, repeated/concurrent shutdown, and stopping before deferred `_core_main` execution.

## Comparing the same workload

The baseline uses the unchanged addon payload from commit `e974bb0e4ed3b202d395af566e652b833f0b1e58`. Both versions use the same core, mod, descriptions, helper cycles, and spawned node. Optional content keys are disabled so an unrelated baseline key-index bug does not interfere with the measurements. The original API had no `shutdown`, so the baseline repeats `launch` calls. The new version explicitly shuts down each context before the next launch.

```sh
python addons/gsom_modapi/tests/lifetime/run.py --godot-wrapper tools/godot.sh --mode before --addon-source build/addons/gsom_modapi/lifetime-before/addons/gsom_modapi --output build/addons/gsom_modapi/lifetime-verified-before
python addons/gsom_modapi/tests/lifetime/run.py --godot-wrapper tools/godot.sh --mode after --output build/addons/gsom_modapi/lifetime-verified-after
```

`--addon-source` points to a saved baseline payload; the example path belongs to the investigation machine. To reproduce elsewhere, obtain the addon payload from the specified commit in a separate directory. The runner does not change working copies or Git revisions.

| Measurement | Baseline | Context with shutdown |
|---|---:|---:|
| Active registry entries on cycle 1 | 2 | 2 |
| Active registry entries on cycle 50 | 100 | 2 |
| Runtime nodes during active cycle 50 | 50 | 1 |
| Tracked instances still alive after the series | 350 of 350 | 0 of 350 |
| Entries after the final shutdown | No shutdown API | 0 |
| Object/resource exit diagnostics | 209 / 7 | 3 / 2 |

The peak number of retained instances after each shutdown in the separate 50-cycle suite was 0, with 0 functional failures. These are object counts, not memory usage in bytes. A long-lived registry during one valid launch is not inherently a bug; this comparison verifies the new relaunch and release contract.

At the context-only stage, 3 objects and 2 script resources remained. That result also reproduced in a minimal project with an empty exported array of its own class. Releasing context instances did not fix the separate script-resource issue. A subsequent change replaced the selectors field with `Array[Resource]`, validating and narrowing entries at the consumption boundary; the results are recorded below.

Three cycles were also run using the complete original demo: one stopped after 0.1 seconds and two after 2.5 seconds. The core was released in all three, with no runtime errors; only the same 3/2 exit diagnostics remained at that stage. All 82 main-project scripts outside `.gdignore` were loaded and checked for instantiability. These checks do not establish graphics, input, multiplayer, PCK unloading, or prolonged stress-test correctness. Comprehensive warnings-as-errors coverage for the inherited project is not yet configured; its existing diagnostic settings were used.

Local Archbox logs: `build/addons/gsom_modapi/lifetime-verified-before-run.log`, `lifetime-verified-after-run.log`, `lifetime-verified-suite-run.log`, `demo-lifetime-run.log`, and `lifetime-full-compile.log`.

## After removing the self-referential field type

`GsomModSelector` changed from `@export var selectors: Array[GsomModSelector]` to `Array[Resource]`. Consumers validate each entry before assigning it to a local `GsomModSelector`. Concrete local array, variable, parameter, and return types are preserved. Minimal probes also showed that an ordinary scalar field of its own class does not reproduce this retention; mentioning the current class is not inherently sufficient to trigger it.

Import, the complete 50-cycle suite, and three complete-demo cycles were repeated. All finished without ERROR/WARNING; the remaining script-resource counts dropped from 3 objects / 2 resources to 0 / 0. All 82 main-project scripts outside `.gdignore` compile. Additional checks cover nested selectors, normalization, query selection, and traversal of an actual cyclic graph; the owner breaks the graph's links after the check.

The negative scenario checks an unrelated Resource and null, then corrects the input and verifies recalculation without a cached partial result:

```sh
python addons/gsom_modapi/tests/lifetime/run.py --godot-wrapper tools/godot.sh --mode invalid-selector --output build/addons/gsom_modapi/invalid-selector-check
```

Logs in Archbox's `build/addons/gsom_modapi/`: `lifetime-no-self-fields-final-run.log`, `invalid-selector-check-run.log`, `import-no-self-fields.log`, `compile-no-self-fields.log`, and `demo-lifetime-no-self-fields.log`. Minimal probes are in `build/addons/self-reference-probes/`: typed-field leaves one script, while raw-field-local, resource-field-local, scalar-self-field, and typed-local-array finish without diagnostics. These observations apply to Godot 4.7.2 on Windows x64.
