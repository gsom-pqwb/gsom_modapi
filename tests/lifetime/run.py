"""Build an isolated fixture project, then run using the caller's pinned Godot wrapper."""
import argparse
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--godot-wrapper", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--mode", choices=("suite", "before", "after", "invalid-selector"), default="suite")
parser.add_argument("--addon-source", type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
payload = args.addon_source.resolve() if args.addon_source else repo / "addons/gsom_modapi"
shutil.copytree(payload, output / "addons/gsom_modapi")
ignored = ["__pycache__", ".gdignore", "project.godot.template", "mods"]
if args.mode == "before":
    ignored.extend(("probe.gd", "comparison_after.gd", "invalid_selector.gd"))
shutil.copytree(Path(__file__).parent, output / "tests/lifetime",
                ignore=shutil.ignore_patterns(*ignored))
shutil.copytree(Path(__file__).parent / "mods", output / "mods")
shutil.copyfile(Path(__file__).parent / "project.godot.template", output / "project.godot")
if args.mode != "suite":
    scene = output / "tests/lifetime/probe.tscn"
    entry = "invalid_selector.gd" if args.mode == "invalid-selector" else f"comparison_{args.mode}.gd"
    scene.write_text(scene.read_text(encoding="utf-8").replace("probe.gd", entry), encoding="utf-8")
expected = {"suite": "LIFETIME cycles=50 peak_retained_after_shutdown=0 failures=0",
            "before": "COMPARE_BEFORE retained=350 tracked=350",
            "after": "COMPARE_AFTER retained=0 tracked=350 entries=0 failures=0",
            "invalid-selector": "INVALID_SELECTOR validated=2 recovered=true"}[args.mode]
for label, flags in (("import", ["--editor", "--import"]), ("run", ["--quit-after", "2000"])):
    result = subprocess.run(["bash", str(args.godot_wrapper.resolve()), "--headless", "--path", str(output), *flags],
                            capture_output=True, text=True, encoding="utf-8", timeout=90)
    log = result.stdout + result.stderr
    (output.parent / (output.name + "-" + label + ".log")).write_text(log, encoding="utf-8")
    print(log)
    if result.returncode != 0 or "SCRIPT ERROR:" in log:
        raise SystemExit(1)
    if args.mode not in ("before", "invalid-selector") and ("ERROR:" in log or "WARNING:" in log):
        raise SystemExit(1)
    if args.mode == "invalid-selector":
        errors = [line for line in log.splitlines() if "ERROR:" in line]
        expected_error = "ERROR: Selector references must contain only non-null GsomModSelector resources"
        if "WARNING:" in log or errors != ([expected_error] * 2 if label == "run" else []):
            raise SystemExit(1)
    if label == "run" and expected not in log:
        raise SystemExit(1)
print("Scenario completed with the expected measurements.")
