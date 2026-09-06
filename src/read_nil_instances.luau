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

return function(collected)
	local scripts, remotes, cached = {}, {}, {}
	local seen = {}
	collected = collected or {}

	-- collected holds instances already queued from the service scan, so the same
	-- script is never decompiled twice through a second discovery route
	local function take(object, path, script_target)
		if seen[object] or collected[object] then return end
		seen[object] = true

		local class_name = object.ClassName
		if SCRIPT_CLASSES[class_name] then
			script_target[claim_path(script_target, path)] = object
		elseif REMOTE_CLASSES[class_name] then
			remotes[claim_path(remotes, path)] = { Name = object.Name, ClassName = class_name, FullName = object:GetFullName() }
		end
	end

	local ok_nil, nil_instances = pcall(fn_getnilinstances)
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

	-- getmodules() exposes cached ModuleScripts that getnilinstances can miss,
	-- including modules whose parent was destroyed after they were required.
	-- modules that still have a parent live somewhere real (Lighting, an
	-- unscanned service, another player) and would be misleading under
	-- nilinstances/, so they are returned separately.
	if fn_getmodules then
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

	return scripts, remotes, cached
end
