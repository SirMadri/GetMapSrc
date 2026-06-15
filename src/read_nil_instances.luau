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

local function sanitize_segment(part)
	part = part:gsub("[\128-\255]+", ""):gsub('%c', '_'):gsub('[\\/*?"<>|%[%]]', "_"):gsub(":", "_"):gsub("%s+$", ""):gsub("^%s+", "")
	return part:sub(1, 25)
end

local function build_path(root_name, object)
	local full_name = object:GetFullName()
	local rest = full_name:sub(#root_name + 2)
	if rest == "" then
		return sanitize_segment(root_name)
	end
	local parts = { sanitize_segment(root_name) }
	for segment in rest:gmatch("[^%.]+") do
		parts[#parts + 1] = sanitize_segment(segment)
	end
	return table.concat(parts, "/"):gsub("//+", "/"):gsub("^/+", ""):gsub("/+$", "")
end

local function path_contains_ignored(path)
	local first = true
	for seg in path:gmatch("[^/]+") do
		if first then first = false; continue end
		if IGNORED_ROOTS[seg] then return true end
	end
	return false
end

return function()
	local scripts, remotes = {}, {}

	for _, root in next, getnilinstances() do
		if IGNORED_ROOTS[root.Name] then continue end
		local root_path = sanitize_segment(root.Name)

		if root:IsA("ModuleScript") or root:IsA("Script") then
			scripts[root_path] = root
		elseif root:IsA("RemoteEvent") or root:IsA("RemoteFunction") or root:IsA("UnreliableRemoteEvent") then
			remotes[root_path] = { Name = root.Name, ClassName = root.ClassName, FullName = root:GetFullName() }
		end

		for _, object in next, root:GetDescendants() do
			local path = build_path(root.Name, object)
			if path_contains_ignored(path) then continue end
			if object:IsA("ModuleScript") or object:IsA("LocalScript") then
				scripts[path] = object
			elseif object:IsA("RemoteEvent") or object:IsA("RemoteFunction") or object:IsA("UnreliableRemoteEvent") then
				remotes[path] = { Name = object.Name, ClassName = object.ClassName, FullName = object:GetFullName() }
			end
		end
	end

	return scripts, remotes
end
