-- nil-parented instance scan
--
-- getnilinstances() returns every cached instance whose Parent is nil, and the
-- DataModel itself has Parent == nil. Walking its descendants re-dumps the whole
-- game, so roots are rejected by class here and not only by name.

local SCRIPT_CLASSES = { ModuleScript = true, LocalScript = true, Script = true }
local REMOTE_CLASSES = { RemoteEvent = true, RemoteFunction = true, UnreliableRemoteEvent = true }

local IGNORED_ROOTS = {
	CoreGui = true,
	CorePackages = true,
	RobloxGui = true,
	LuaPackages = true,
	GamepadMenu = true,
	VideoRecordingFolder = true,
	PreRobuxPrompt = true,
	RobloxPromptGui = true,
	TopBarApp = true,
	VoiceChatGui = true,
	BubbleChatSoundManager = true,
	AvatarEditorService = true,
	ProximityPromptTemplates = true,
	Workspace = true,
	_Index = true,
	node_modules = true,
	rbxts_include = true,
}

-- a plain Script only runs on the client with RunContext = Client; a Legacy or
-- Server one never replicates its bytecode, so decompiling it always fails
local function is_client_script(object)
	if object.ClassName ~= "Script" then return true end
	local ok, run_context = pcall(function() return object.RunContext end)
	return ok and run_context == Enum.RunContext.Client
end

-- safety rails: a single huge orphan tree must not be able to freeze the dump
local MAX_DESCENDANTS_PER_ROOT = 20000
local YIELD_EVERY = 2000

-- executor functions live in the lexical global scope on some executors and in
-- getgenv() on others; resolve both so UNC.luau and this module agree
local genv = getgenv()

local function pick(lexical, name)
	if lexical ~= nil then return lexical end
	local ok, value = pcall(rawget, genv, name)
	if ok and value ~= nil then return value end
	return nil
end

local fn_getnilinstances = pick(getnilinstances, "getnilinstances")
local fn_getmodules = pick(getmodules, "getmodules")
local fn_getrunningscripts = pick(getrunningscripts, "getrunningscripts")
local fn_getactors = pick(getactors, "getactors")

local function sanitize_segment(part)
	part = part:gsub("[\128-\255]+", ""):gsub('%c', '_'):gsub('[\/*?"<>|%[%]]', "_"):gsub(":", "_"):gsub("%s+$", ""):gsub("^%s+", "")
	return part:sub(1, 25):gsub("%s+$", "")
end

-- returns nil when any segment is an ignored container, so CoreGui-style trees
-- reached through getmodules() are dropped instead of dumped
local function full_name_to_path(full_name)
	local parts = {}
	for segment in full_name:gmatch("[^%.]+") do
		if IGNORED_ROOTS[segment] then return nil end
		parts[#parts + 1] = sanitize_segment(segment)
	end
	if #parts == 0 then return nil end
	return (table.concat(parts, "/"):gsub("//+", "/"):gsub("^/+", ""):gsub("/+$", ""))
end

-- two different orphans can sanitize down to the same path; never let one
-- silently overwrite the other
local function claim_path(map, path)
	if map[path] == nil then return path end
	local index = 2
	while map[path .. "_" .. index] ~= nil do index += 1 end
	return path .. "_" .. index
end

-- the DataModel, services and Players all have their descendants walked by
-- read_game already; treating them as orphan roots duplicates the entire dump
local function is_excluded_root(root)
	if root == game then return true end
	if IGNORED_ROOTS[root.Name] then return true end

	local ok, is_container = pcall(function()
		return root:IsA("DataModel") or root:IsA("ServiceProvider") or root:IsA("Player")
	end)
	return ok and is_container
end

-- options.nil_instances / options.running (both default on) pick which sources
-- are mined, so dump_nil_instances = false does not also disable the running scan
return function(collected, options)
	local scripts, remotes, cached, running = {}, {}, {}, {}
	local seen = {}
	collected = collected or {}
	options = options or {}
	local use_nil = options.nil_instances ~= false
	local use_running = options.running ~= false

	-- collected holds instances already queued from the service scan, so the same
	-- script is never decompiled twice through a second discovery route
	local function take(object, path, script_target)
		if seen[object] or collected[object] then return end
		seen[object] = true

		local class_name = object.ClassName
		if SCRIPT_CLASSES[class_name] then
			if is_client_script(object) then script_target[claim_path(script_target, path)] = object end
		elseif REMOTE_CLASSES[class_name] then
			remotes[claim_path(remotes, path)] = { Name = object.Name, ClassName = class_name, FullName = object:GetFullName() }
		end
	end

	local ok_nil, nil_instances = false, nil
	if use_nil and fn_getnilinstances then ok_nil, nil_instances = pcall(fn_getnilinstances) end
	if ok_nil and type(nil_instances) == "table" then
		for _, root in next, nil_instances do
			if typeof(root) ~= "Instance" then continue end
			if root.Parent ~= nil then continue end
			if is_excluded_root(root) then continue end

			local root_path = sanitize_segment(root.Name)
			if root_path ~= "" then take(root, root_path, scripts) end

			local ok_desc, descendants = pcall(root.GetDescendants, root)
			if not ok_desc then continue end

			if #descendants > MAX_DESCENDANTS_PER_ROOT then
				warn(("-- skipping nil root '%s': %d descendants (limit %d)"):format(root.Name, #descendants, MAX_DESCENDANTS_PER_ROOT))
				continue
			end

			for index, object in next, descendants do
				if index % YIELD_EVERY == 0 then task.wait() end
				local ok_name, full_name = pcall(object.GetFullName, object)
				if not ok_name then continue end
				local path = full_name_to_path(full_name)
				if path then take(object, path, scripts) end
			end
		end
	end

	-- getrunningscripts() lists scripts that are alive right now, including ones
	-- outside every scanned service (PlayerScripts, Lighting, ...) and orphans in
	-- trees the nil scan skipped for size. it runs before getmodules so a running
	-- module is filed here and not under _CachedModules. the docs do not say
	-- whether CoreGui scripts are listed, so full_name_to_path filters them anyway.
	-- parented scripts are returned separately for the same reason as cached ones.
	if use_running and fn_getrunningscripts then
		local ok_running, running_scripts = pcall(fn_getrunningscripts)
		if ok_running and type(running_scripts) == "table" then
			for index, script_obj in next, running_scripts do
				if index % YIELD_EVERY == 0 then task.wait() end
				if typeof(script_obj) ~= "Instance" then continue end
				if seen[script_obj] or collected[script_obj] then continue end

				local ok_name, full_name = pcall(script_obj.GetFullName, script_obj)
				if not ok_name then continue end
				local path = full_name_to_path(full_name)
				if not path then continue end

				take(script_obj, path, script_obj.Parent == nil and scripts or running)
			end
		end
	end

	-- getactors() lists active Actors; scripts under one run in a parallel state and
	-- may sit outside every scanned service. only the Actor's own descendants are
	-- read (no foreign-state access), and anything already seen is skipped. the
	-- docs do not say whether nil-parented Actors are listed, so the target bucket
	-- follows the Actor's own parent.
	if use_running and fn_getactors then
		local ok_actors, actors = pcall(fn_getactors)
		if ok_actors and type(actors) == "table" then
			for _, actor in next, actors do
				if typeof(actor) ~= "Instance" or is_excluded_root(actor) then continue end

				local ok_desc, descendants = pcall(actor.GetDescendants, actor)
				if not ok_desc then continue end

				if #descendants > MAX_DESCENDANTS_PER_ROOT then
					warn(("-- skipping actor '%s': %d descendants (limit %d)"):format(actor.Name, #descendants, MAX_DESCENDANTS_PER_ROOT))
					continue
				end

				local target = actor.Parent == nil and scripts or running
				for index, object in next, descendants do
					if index % YIELD_EVERY == 0 then task.wait() end
					if seen[object] or collected[object] then continue end

					local ok_name, full_name = pcall(object.GetFullName, object)
					if not ok_name then continue end
					local path = full_name_to_path(full_name)
					if path then take(object, path, target) end
				end
			end
		end
	end

	-- getmodules() exposes cached ModuleScripts that getnilinstances can miss,
	-- including modules whose parent was destroyed after they were required.
	-- modules that still have a parent live somewhere real (Lighting, an
	-- unscanned service, another player) and would be misleading under
	-- nilinstances/, so they are returned separately.
	if use_nil and fn_getmodules then
		local ok_modules, modules = pcall(fn_getmodules)
		if ok_modules and type(modules) == "table" then
			for index, module in next, modules do
				if index % YIELD_EVERY == 0 then task.wait() end
				if typeof(module) ~= "Instance" then continue end
				if seen[module] or collected[module] then continue end

				local ok_name, full_name = pcall(module.GetFullName, module)
				if not ok_name then continue end
				local path = full_name_to_path(full_name)
				if not path then continue end

				take(module, path, module.Parent == nil and scripts or cached)
			end
		end
	end

	return scripts, remotes, cached, running
end
