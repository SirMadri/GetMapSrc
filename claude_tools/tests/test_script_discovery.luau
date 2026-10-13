-- offline test for script discovery (read_game, read_nil_instances, blocked_modules)
--
-- runs under the plain `luau` CLI with mocked Instances, so it validates the
-- discovery logic only: it says nothing about real executor behavior.
-- run it through claude_tools/tests/run_script_discovery.py (needs `luau` on
-- PATH, or pass --luau <path>); it injects the src modules before this file

-- // Roblox / executor mocks
local mock = { nil_instances = {}, modules = {}, running = {}, actors = {} }

game = { __name = "game", children = {} }
Enum = { RunContext = { Legacy = "Legacy", Server = "Server", Client = "Client" } }
task = { wait = function() end }
warn = function() end
getgenv = function() return {} end
typeof = function(value) return type(value) == "table" and value.__inst and "Instance" or type(value) end

getnilinstances = function() return mock.nil_instances end
getmodules = function() return mock.modules end
getrunningscripts = function() return mock.running end
getactors = function() return mock.actors end

local function make(class_name, name, parent, props)
	local object = { __inst = true, ClassName = class_name, Name = name, Parent = parent, children = {} }
	for key, value in next, props or {} do object[key] = value end
	if parent then table.insert(parent.children, object) end

	function object.GetFullName(self)
		local parts, cursor = {}, self
		while cursor and cursor ~= game do
			table.insert(parts, 1, cursor.Name)
			cursor = cursor.Parent
		end
		return table.concat(parts, ".")
	end
	function object.GetChildren(self) return self.children end
	function object.GetDescendants(self)
		local out = {}
		local function walk(node) for _, child in next, node.children do table.insert(out, child); walk(child) end end
		walk(self)
		return out
	end
	function object.IsA(self, class) return self.ClassName == class end
	return object
end

-- // Harness
local failures, checks = 0, 0
local function check(label, condition)
	checks += 1
	if not condition then failures += 1; print("FAIL: " .. label) end
end

local function count(map) local n = 0; for _ in next, map do n += 1 end; return n end
local function has_value(map, value) for _, v in next, map do if v == value then return true end end; return false end

-- __modules is prepended by run_script_discovery.py: it holds each src module as
-- a function, so the modules share this chunk's mocked globals (the luau CLI
-- sandboxes require()d files, which would hide the mocks from them)
local read_nil_instances = __modules.read_nil_instances()
local read_game = __modules.read_game()
local blocked_modules = __modules.blocked_modules()

-- // Fixture
local players = make("Players", "Players", game)
local player = make("Player", "SirMadri", players)
local player_scripts = make("PlayerScripts", "PlayerScripts", player)
local lighting = make("Lighting", "Lighting", game)
local core_gui = make("CoreGui", "CoreGui", game)
local workspace_svc = make("Workspace", "Workspace", game)

local hud = make("LocalScript", "CoinHUD", player_scripts)
local light_script = make("LocalScript", "Day", lighting)
local core_script = make("LocalScript", "Overlay", make("ScreenGui", "RobloxGui", core_gui))
local orphan = make("LocalScript", "Orphan", nil)
local server_script = make("Script", "ServerOnly", lighting, { RunContext = Enum.RunContext.Legacy })
local client_script = make("Script", "ClientRun", lighting, { RunContext = Enum.RunContext.Client })
local already = make("LocalScript", "Already", workspace_svc)
local actor = make("Actor", "Worker", lighting)
local actor_script = make("Script", "ActorScript", actor, { RunContext = Enum.RunContext.Client })
local actor_server = make("Script", "ActorServer", actor, { RunContext = Enum.RunContext.Server })
local cached_module = make("ModuleScript", "Cached", lighting)

-- // read_nil_instances: running + actors
mock.running = { hud, light_script, core_script, orphan, server_script, client_script, already, hud, "junk" }
mock.actors = { actor }
mock.modules = { cached_module, hud }
mock.nil_instances = {}

local scripts, _, cached, running = read_nil_instances({ [already] = true })

check("parented running script goes to running", has_value(running, hud))
check("running script outside scanned services goes to running", has_value(running, light_script))
check("nil-parented running script goes to scripts", has_value(scripts, orphan))
check("CoreGui running script is dropped", not has_value(running, core_script) and not has_value(scripts, core_script))
check("Legacy server Script is dropped", not has_value(running, server_script))
check("RunContext Client Script is kept", has_value(running, client_script))
check("already collected script is skipped", not has_value(running, already) and not has_value(scripts, already))
check("duplicate in running list appears once", (function() local n = 0; for _, v in next, running do if v == hud then n += 1 end end; return n end)() == 1)
check("actor client Script is kept", has_value(running, actor_script))
check("actor server Script is dropped", not has_value(running, actor_server))
check("running module is not also cached", not has_value(cached, hud))
check("cached module without parent in scan stays in cached", has_value(cached, cached_module))

-- // options toggles
local s2, _, c2, r2 = read_nil_instances({}, { running = false })
check("running = false returns no running scripts", count(r2) == 0)
check("running = false still returns cached modules", has_value(c2, cached_module))

local nil_only = make("LocalScript", "NilOnly", nil)
mock.nil_instances = { nil_only }
local s_default = read_nil_instances({})
check("default scan reads nil roots", has_value(s_default, nil_only))
local s3, _, c3, r3 = read_nil_instances({}, { nil_instances = false })
check("nil_instances = false skips nil roots", not has_value(s3, nil_only))
check("nil_instances = false skips getmodules", count(c3) == 0)
check("nil_instances = false keeps running scan", has_value(r3, hud))

-- // read_game: server Script filtering
local service = make("ReplicatedStorage", "ReplicatedStorage", game)
local rs_local = make("LocalScript", "L", service)
local rs_module = make("ModuleScript", "M", service)
local rs_legacy = make("Script", "Legacy", service, { RunContext = Enum.RunContext.Legacy })
local rs_server = make("Script", "Server", service, { RunContext = Enum.RunContext.Server })
local rs_client = make("Script", "Client", service, { RunContext = Enum.RunContext.Client })
service.GetDescendants = function(self) return { rs_local, rs_module, rs_legacy, rs_server, rs_client } end

local game_scripts = read_game(service, false)
check("read_game keeps LocalScript", has_value(game_scripts, rs_local))
check("read_game keeps ModuleScript", has_value(game_scripts, rs_module))
check("read_game keeps RunContext Client Script", has_value(game_scripts, rs_client))
check("read_game drops Legacy Script", not has_value(game_scripts, rs_legacy))
check("read_game drops Server Script", not has_value(game_scripts, rs_server))

-- // blocked_modules: built-in list and config.blocked_paths
check("blocked: built-in entry still matches", blocked_modules(2753915549, "Main/UIController/SetUpSkills") == true)
check("blocked: built-in entry is place-specific", blocked_modules(1, "Main/UIController/SetUpSkills") == false)
check("blocked: extra suffix matches any place", blocked_modules(1, "A/B/Crash", { "B/Crash" }) == true)
check("blocked: extra suffix respects path boundary", blocked_modules(1, "A/XB/Crash", { "B/Crash" }) == false)
check("blocked: bad extra entries are ignored", blocked_modules(1, "A/B", { 5, "" }) == false)
check("blocked: nil extra is fine", blocked_modules(1, "A/B", nil) == false)

print(("%d checks, %d failed"):format(checks, failures))
if failures > 0 then error("test failed") end
