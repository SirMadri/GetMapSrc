"""Runs test_script_discovery.luau against the real src modules using the luau CLI.

The luau CLI sandboxes every require()d file, so mocked globals set by the test
would be invisible to the modules. This runner wraps each module's source in a
function and prepends them to the test, so everything shares one chunk.

usage (from anywhere):
    python claude_tools/tests/run_script_discovery.py [--luau PATH_TO_LUAU]
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src"
TEST = Path(__file__).with_name("test_script_discovery.luau")
OUTPUT = ROOT / "claude_tools" / "output"
MODULES = ["read_nil_instances", "read_game", "blocked_modules"]


def build_combined() -> str:
    parts = ["local __modules = {}\n"]
    for name in MODULES:
        source = (SRC / f"{name}.luau").read_text(encoding="utf-8")
        parts.append(f"__modules.{name} = function()\n{source}\nend\n")
    parts.append(TEST.read_text(encoding="utf-8"))
    return "".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default=shutil.which("luau"), help="path to the luau CLI (default: luau on PATH)")
    args = parser.parse_args()
    if not args.luau:
        print("luau CLI not found; pass --luau PATH", file=sys.stderr)
        return 2

    OUTPUT.mkdir(parents=True, exist_ok=True)
    combined = OUTPUT / "test_script_discovery.combined.luau"
    combined.write_text(build_combined(), encoding="utf-8")

    result = subprocess.run([args.luau, str(combined)], capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
