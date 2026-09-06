local function sanitize_path(full_name, service_name)
	local path = full_name:sub(#service_name + 2)
	path = path:gsub("[^.]+", function(part)
		part = part:gsub("[\128-\255]+", ""):gsub('%c', '_'):gsub('[\/*?"<>|%[%]]', "_"):gsub(":", "_"):gsub("%s+$", ""):gsub("^%s+", "")
		return part:sub(1, 25):gsub("%s+$", "")
	end)

	return path:gsub("%.", "/"):gsub("//+", "/"):gsub("^/+", ""):gsub("/+$", "")
end

-- Script is included because RunContext = Client makes a plain Script run on the
-- client; LocalScript and Script are siblings under BaseScript, not parent/child
local SCRIPT_CLASSES   = { ModuleScript = true, LocalScript = true, Script = true }
local REMOTE_CLASSES   = { RemoteEvent = true, RemoteFunction = true, UnreliableRemoteEvent = true }
local BINDABLE_CLASSES = { BindableEvent = true, BindableFunction = true }
local VALUE_CLASSES    = {
	StringValue = true, NumberValue = true, IntValue = true, BoolValue = true,
	Vector3Value = true, Color3Value = true, CFrameValue = true, ObjectValue = true,
}

local IGNORED_SEGMENTS = { node_modules = true, rbxts_include = true, _Index = true }

local function path_is_ignored(path)
	for seg in path:gmatch("[^/]+") do
		if IGNORED_SEGMENTS[seg] then return true end
	end
	return false
end

-- sibling instances often share a name, and sanitize_path truncates each segment
-- to 25 chars, so distinct objects collide; suffix instead of overwriting
local function claim_path(map, path)
	if map[path] == nil then return path end
	local index = 2
	while map[path .. "_" .. index] ~= nil do index += 1 end
	return path .. "_" .. index
end

return function(service, dump_map)
	local scripts, remotes, meta_instances, values, bindables = {}, {}, {}, {}, {}
	local descendants = service:GetDescendants()

	-- one upward pass gives every ancestor its descendant count; instance_meta
	-- used to call GetDescendants() per instance instead, which is quadratic
	local descendant_counts = {}
	if dump_map then
		for _, object in next, descendants do
			local parent = object.Parent
			while parent ~= nil and parent ~= service do
				descendant_counts[parent] = (descendant_counts[parent] or 0) + 1
				parent = parent.Parent
			end
		end
	end

	for _, object in next, descendants do
		local path = sanitize_path(object:GetFullName(), service.Name)
		if path_is_ignored(path) then continue end
		local class_name = object.ClassName
		if SCRIPT_CLASSES[class_name] then
			scripts[claim_path(scripts, path)] = object
		elseif REMOTE_CLASSES[class_name] then
			remotes[claim_path(remotes, path)] = { Name = object.Name, ClassName = class_name, FullName = object:GetFullName() }
		elseif BINDABLE_CLASSES[class_name] then
			bindables[claim_path(bindables, path)] = { Name = object.Name, ClassName = class_name, FullName = object:GetFullName() }
		elseif VALUE_CLASSES[class_name] then
			local ok, val = pcall(function() return object.Value end)
			values[claim_path(values, path)] = { class_name = class_name, value = ok and val or nil }
		elseif dump_map then
			local is_gui = object:IsA("GuiObject") or object:IsA("LayerCollector") or object:IsA("UIBase")
			if is_gui or #object:GetChildren() > 0 then
				meta_instances[claim_path(meta_instances, path)] = object
			end
		end
	end

	return scripts, remotes, meta_instances, values, bindables, descendant_counts
end
