# claude_tools

Project-local test and helper tools.

| Path | Purpose | Invocation |
|---|---|---|
| `tests/run_script_discovery.py` | Runs `tests/test_script_discovery.luau` against the real `src/` modules (`read_nil_instances`, `read_game`, `blocked_modules`) with mocked Instances | `python claude_tools/tests/run_script_discovery.py --luau <path to luau CLI>` |
| `tests/test_script_discovery.luau` | The test itself: running/actors discovery, server `Script` filtering, option toggles, `blocked_paths` | run via the Python runner (it injects the modules) |

Notes:
- Needs the official `luau` CLI (https://github.com/luau-lang/luau/releases); omit `--luau` if it is on `PATH`.
- The runner writes a combined file to `claude_tools/output/` (git-ignored). Nothing in `src/` is modified.
- Mocks only: this validates discovery logic, not real executor behavior.
