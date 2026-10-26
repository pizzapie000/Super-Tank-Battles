#!/usr/bin/env python3
"""Run isolated, sequential Godot performance experiments and retain raw frames.

Examples:
  python3 tools/profile_battle.py --modes baseline blank no_tanks no_world
  python3 tools/profile_battle.py --instrument --modes baseline freeze_tank_art
  python3 tools/profile_battle.py --renderer metal --modes baseline --sample --frames 600

Instrumentation is injected into a temporary copy, never the source project.
"""
import argparse
import hashlib
import json
from pathlib import Path
import random
import re
import shutil
import subprocess
import tempfile
import time


PROFILE_FUNCTIONS = {
    "scripts/tank.gd": ["_physics_process", "_draw"],
    "scripts/enemy_tank.gd": ["control_step", "aimed_path", "drive_toward"],
    "scripts/story/story_tank.gd": ["_physics_process", "_draw"],
    "scripts/story/story_enemy.gd": ["_process", "_draw"],
    "scripts/story/adventure.gd": ["_process", "navigation_path", "plan_enemy_shot", "evasion_vector", "rebuild_navigation"],
    "scripts/duel_arena.gd": ["_physics_process"],
    "scripts/shell.gd": ["_physics_process", "_draw", "resolve_interceptions"],
    "scripts/tank_ground_feedback.gd": ["_draw", "step"],
    "scripts/mission_navigation.gd": ["path", "build"],
    "scripts/shot_planner.gd": ["solve"],
    "scripts/tank_art.gd": ["tracks", "chassis", "armor", "turret", "barrel"],
    "scripts/story/cover_tree.gd": ["_draw", "draw_shadow", "draw_trunk"],
    "scripts/story/environment_barricade.gd": ["_draw"],
}


def argument_names(parameters):
    parts, start, depth = [], 0, 0
    for index, char in enumerate(parameters):
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "," and depth == 0:
            parts.append(parameters[start:index])
            start = index + 1
    parts.append(parameters[start:])
    return [part.split(":", 1)[0].split("=", 1)[0].strip() for part in parts if part.strip()]


def instrument(project, output, timing=True):
    clone = Path(tempfile.mkdtemp(prefix="instrumented-project-", dir=output))
    shutil.copytree(project, clone, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns(".git", ".godot", "builds", ".DS_Store"))
    manifest = []
    for relative, functions in PROFILE_FUNCTIONS.items():
        target = clone / relative
        source = target.read_text()
        key = Path(relative).stem
        for name in functions if timing else []:
            pattern = re.compile(r"^(static )?func " + re.escape(name) + r"\((.*)\)(\s*->\s*[^:]+)?:[^\n]*$", re.M)
            matches = list(pattern.finditer(source))
            if len(matches) != 1:
                raise RuntimeError(f"Expected one {relative}:{name}, got {len(matches)}")
            match = matches[0]
            implementation = f"_profile_impl_{key}_{name.lstrip('_')}"
            signature = match.group(0)
            renamed = signature.replace(f"func {name}(", f"func {implementation}(", 1)
            source = source[:match.start()] + renamed + source[match.end():]
            call = f"{implementation}({', '.join(argument_names(match.group(2)))})"
            returns = bool(match.group(3) and match.group(3).strip() != "-> void")
            wrapper = f'\n\n{signature}\n\tpreload("res://tests/profiling/profile_metrics.gd").begin("{key}.{name}")\n'
            wrapper += f"\tvar _profile_result = {call}\n" if returns else f"\t{call}\n"
            wrapper += '\tpreload("res://tests/profiling/profile_metrics.gd").end()\n'
            if returns:
                wrapper += "\treturn _profile_result\n"
            source += wrapper
            manifest.append(f"{relative}:{name}")
        if relative in ["scripts/tank.gd", "scripts/story/story_enemy.gd", "scripts/story/story_tank.gd"]:
            helper = f"_profile_redraw_{key}"
            source = re.sub(r"(?<![.\w])queue_redraw\(\)", helper + "()", source)
            gate = 'not preload("res://tests/profiling/profile_metrics.gd").freeze_tank_art and not preload("res://tests/profiling/profile_metrics.gd").render_once'
            if key == 'story_enemy':
                gate += ' and not preload("res://tests/profiling/profile_metrics.gd").suppress_enemy_idle_redraw'
            source += f'\n\nfunc {helper}() -> void:\n\tif {gate}: queue_redraw()\n'
        if timing and relative == "scripts/tank_art.gd":
            source = re.sub(r'(canvas\.draw_(?:line|polyline|arc)\([^\n]*), true\)', r'\1, not preload("res://tests/profiling/profile_metrics.gd").disable_tank_aa)', source)
        target.write_text(source)
    (output / "instrumentation.json").write_text(json.dumps({"project": str(clone), "functions": manifest, "script_timing": timing}, indent=2))
    return clone


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--godot", type=Path, default=Path.home() / "Downloads/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--output", type=Path, default=Path("builds/profiling/session"))
    parser.add_argument("--modes", nargs="+", default=["baseline", "blank", "no_world", "no_tanks", "no_marks", "no_projectiles", "no_hud"])
    parser.add_argument("--renderer", choices=["gl", "metal", "headless"], default="gl")
    parser.add_argument("--checkpoint", type=int, default=8)
    parser.add_argument("--players", type=int, default=2)
    parser.add_argument("--frames", type=int, default=300)
    parser.add_argument("--repeats", type=int, default=1)
    parser.add_argument("--resolution", default="1152x720")
    parser.add_argument("--instrument", action="store_true")
    parser.add_argument("--redraw-only", action="store_true", help="isolated redraw prototype without function timing wrappers")
    parser.add_argument("--force-render", action="store_true", help="explicit diagnostic drawing to bypass window occlusion; verify against a normal baseline")
    parser.add_argument("--stable-geometry", action="store_true", help="keep mine-breakable walls intact for paired visual microbenchmarks")
    parser.add_argument("--real-time-seconds", type=float, default=0, help="omit fixed-FPS simulation and sample this many seconds of real play")
    parser.add_argument("--sample", action="store_true", help="native CPU samples; use >=600 measured frames")
    args = parser.parse_args()
    if args.instrument and args.redraw_only:
        parser.error("Choose either full instrumentation or the redraw-only prototype")
    if not 0 <= args.checkpoint <= 19 or not 1 <= args.players <= 4 or not 120 <= args.frames <= 3600 or args.repeats < 1 or args.real_time_seconds < 0:
        parser.error("Use checkpoint 0–19, players 1–4, frames 120–3600, positive repeats, and nonnegative real-time seconds")
    supported = {"baseline", "timers_off", "blank", "no_world", "no_tanks", "no_marks", "no_projectiles", "no_hud", "no_trees", "no_solid_props", "no_render_loop", "freeze_tank_art", "single_enemy_redraw", "no_tank_aa", "render_once"}
    if set(args.modes) - supported:
        parser.error("Unknown experiment mode: " + ", ".join(sorted(set(args.modes) - supported)))
    args.project, args.godot = args.project.resolve(), args.godot.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").touch()
    if args.sample and args.frames < 600:
        parser.error("Native CPU sampling needs at least 600 measured frames")
    if args.force_render and args.renderer == "metal":
        parser.error("Use normal presentation for Metal; pending resource processing can otherwise add a second render pass")
    isolated = args.instrument or args.redraw_only
    if not isolated and any(mode in ["freeze_tank_art", "single_enemy_redraw", "no_tank_aa", "render_once"] for mode in args.modes):
        parser.error("The draw-generation experiments require --instrument or --redraw-only (an isolated copy)")
    if args.redraw_only and "no_tank_aa" in args.modes:
        parser.error("The antialiasing experiment requires --instrument")
    project = instrument(args.project, output, timing=args.instrument) if isolated else args.project
    if isolated:
        with (output / "import.log").open("w") as log:
            subprocess.run([str(args.godot), "--headless", "--editor", "--path", str(project), "--import", "--quit"], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=60)
        with (output / "parse.log").open("w") as log:
            subprocess.run([str(args.godot), "--headless", "--path", str(project), "--check-only", "--script", "res://tests/profiling/deep_battle_profile.gd"], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)
        if "SCRIPT ERROR" in (output / "parse.log").read_text():
            raise RuntimeError("Instrumented scripts failed to parse; see parse.log")
    # Randomized ordering and repeats reduce warm-cache and gradual temperature bias.
    cases = [(mode, repeat) for repeat in range(args.repeats) for mode in args.modes]
    random.Random(143).shuffle(cases)
    completed = []
    for mode, repeat in cases:
        case = f"{mode}-{args.renderer}-{args.players}p-r{repeat}"
        result = output / (case + ".json")
        ready = Path(str(result) + ".ready")
        if result.exists():
            raise RuntimeError(f"Refusing to replace a previous result: {result}")
        ready.unlink(missing_ok=True)
        command = [str(args.godot), "--path", str(project), "--audio-driver", "Dummy"]
        if args.real_time_seconds <= 0: command += ["--fixed-fps", "60"]
        if args.renderer == "headless":
            command += ["--headless"]
        else:
            command += ["--always-on-top", "--position", "50,50", "--resolution", args.resolution]
        if args.renderer == "metal":
            command += ["--rendering-method", "mobile", "--rendering-driver", "metal"]
        command += ["--script", "res://tests/profiling/deep_battle_profile.gd", "--", mode, str(args.checkpoint), str(args.players), str(args.frames), str(result), "1" if args.instrument else "0", "1" if args.force_render else "0", "1" if args.stable_geometry else "0", str(args.real_time_seconds)]
        print(f"Running {case}", flush=True)
        started = time.monotonic()
        with (output / (case + ".log")).open("w") as log:
            child = subprocess.Popen(command, cwd=project, stdout=log, stderr=subprocess.STDOUT)
            try:
                if args.sample:
                    while not ready.exists():
                        if child.poll() is not None or time.monotonic() - started > 60:
                            raise RuntimeError("Process exited or timed out before the warmup signal")
                        time.sleep(.1)
                    sample = subprocess.run(["/usr/bin/sample", str(child.pid), "6", "1", "-mayDie", "-file", str(output / (case + ".sample.txt"))], capture_output=True, text=True, timeout=30)
                    (output / (case + ".sample-status.txt")).write_text(sample.stdout + sample.stderr)
                code = child.wait(timeout=max(120, args.frames * .15))
                if code != 0 or not result.exists():
                    raise RuntimeError(f"{case} failed (exit {code}); see its log")
            finally:
                if child.poll() is None:
                    child.terminate()
                    try:
                        child.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        child.kill()
                        child.wait()
        data = json.loads(result.read_text())
        expected_drawing = args.renderer != "headless" and mode != "no_render_loop"
        data["valid_render_coverage"] = not expected_drawing or abs(data["rendered_frames"] - data["frame_count"]) <= max(2, data["frame_count"] * .02)
        data["experiment"] = {"command": command, "sampled": args.sample, "instrumented": args.instrument, "redraw_only": args.redraw_only, "elapsed_seconds": time.monotonic() - started,
                               "harness_sha256": hashlib.sha256((project / "tests/profiling/deep_battle_profile.gd").read_bytes()).hexdigest()}
        result.write_text(json.dumps(data, indent=2))
        summary = {"case": case, "file": str(result), "frame_ms": data["summary"]["frame_ms"], "render_cpu_ms": data["summary"]["viewport_cpu_ms"], "render_gpu_ms": data["summary"]["viewport_gpu_ms"], "draw_calls": data["summary"]["draw_calls"]["median"], "rendered_frames": data["rendered_frames"], "geometry_unchanged": data["geometry_hash"] == data["geometry_hash_end"]}
        completed.append(summary)
        (output / "index.json").write_text(json.dumps(completed, indent=2))
        print(json.dumps(summary), flush=True)
        if not data["valid_render_coverage"]:
            raise RuntimeError("macOS skipped rendering part of this case; result marked invalid. Keep the profiling window visible and rerun in a fresh output folder.")
        if "SCRIPT ERROR" in (output / (case + ".log")).read_text():
            raise RuntimeError(f"{case} logged a script error; see its log")
    print(f"Results: {output}", flush=True)


if __name__ == "__main__":
    main()
