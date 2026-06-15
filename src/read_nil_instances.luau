local IGNORED_ROOTS = {
	CoreGui = true,
	CorePackages = true,
	RobloxGui = true,
	LuaPackages = true,
	GamepadMenu = true,
	VideoRecordingFolder = true,
}

local function sanitize_segment(part)
	part = part:gsub("[\128-\255]+", ""):gsub('%c', '_'):gsub('[\\/*?"<>|]', "_"):gsub(":", "_"):gsub("%s+$", ""):gsub("^%s+", "")
	return part:sub(1, 25)
end

local function build_path(root_name, object)
	local full = object:GetFullName():gsub("^" .. root_name .. "%.?", "")
	if full == "" then
		return sanitize_segment(root_name)
	end
	local parts = { sanitize_segment(root_name) }
	for segment in full:gmatch("[^%.]+") do
		parts[#parts + 1] = sanitize_segment(segment)
	end
	return table.concat(parts, "/"):gsub("//+", "/"):gsub("^/+", ""):gsub("/+$", "")
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
			if object:IsA("ModuleScript") or object:IsA("LocalScript") then
				scripts[path] = object
			elseif object:IsA("RemoteEvent") or object:IsA("RemoteFunction") or object:IsA("UnreliableRemoteEvent") then
				remotes[path] = { Name = object.Name, ClassName = object.ClassName, FullName = object:GetFullName() }
			end
		end
	end

	return scripts, remotes
end
