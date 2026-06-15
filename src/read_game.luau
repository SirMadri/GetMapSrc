local function sanitize_path(full_name, service_name)
	local path = full_name:sub(#service_name + 2)
	path = path:gsub("[^.]+", function(part)
		part = part:gsub("[\128-\255]+", ""):gsub('%c', '_'):gsub('[\\/*?"<>|%[%]]', "_"):gsub(":", "_"):gsub("%s+$", ""):gsub("^%s+", "")
		return part:sub(1, 25)
	end)

	return path:gsub("%.", "/"):gsub("//+", "/"):gsub("^/+", ""):gsub("/+$", "")
end

local SCRIPT_CLASSES   = { ModuleScript = true, LocalScript = true }
local REMOTE_CLASSES   = { RemoteEvent = true, RemoteFunction = true, UnreliableRemoteEvent = true }
local BINDABLE_CLASSES = { BindableEvent = true, BindableFunction = true }
local VALUE_CLASSES    = {
	StringValue = true, NumberValue = true, IntValue = true, BoolValue = true,
	Vector3Value = true, Color3Value = true, CFrameValue = true, ObjectValue = true,
}

local IGNORED_SEGMENTS = { node_modules = true }

local function path_is_ignored(path)
	for seg in path:gmatch("[^/]+") do
		if IGNORED_SEGMENTS[seg] then return true end
	end
	return false
end

return function(service, dump_map)
	local scripts, remotes, meta_instances, values, bindables = {}, {}, {}, {}, {}
	for _, object in next, service:GetDescendants() do
		local path = sanitize_path(object:GetFullName(), service.Name)
		if path_is_ignored(path) then continue end
		if SCRIPT_CLASSES[object.ClassName] then
			scripts[path] = object
		elseif REMOTE_CLASSES[object.ClassName] then
			remotes[path] = { Name = object.Name, ClassName = object.ClassName, FullName = object:GetFullName() }
		elseif BINDABLE_CLASSES[object.ClassName] then
			bindables[path] = { Name = object.Name, ClassName = object.ClassName, FullName = object:GetFullName() }
		elseif VALUE_CLASSES[object.ClassName] then
			local ok, val = pcall(function() return object.Value end)
			values[path] = { class_name = object.ClassName, value = ok and val or nil }
		elseif dump_map then
			local is_gui = object:IsA("GuiObject") or object:IsA("LayerCollector") or object:IsA("UIBase")
			if is_gui or #object:GetChildren() > 0 then
				meta_instances[path] = object
			end
		end
	end

	return scripts, remotes, meta_instances, values, bindables
end
