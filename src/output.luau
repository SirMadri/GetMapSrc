local function sanitize_name(s)
	return (s:gsub("[\128-\255]+", ""):gsub('%c', '_'):gsub('[\\*?"<>|]', "_"):gsub(":", "_"):gsub("//+", "/"):gsub("/+$", ""))
end

local function make_dir(path)
	local current = ""
	for segment in path:gmatch("[^/]+") do
		current = current ~= "" and current .. "/" .. segment or segment
		if not isfolder(current) then pcall(makefolder, current) end
	end
end

return function(game_name)
	game_name = sanitize_name(game_name):sub(1, 25)
	local base_dir = "_GetMapSrc/" .. game_name .. "/" .. os.date("%H-%M-%S")
	make_dir(base_dir)
	print("-- output dir: " .. base_dir)

	return function(service_name, path, source, is_remote)
		service_name = sanitize_name(service_name)
		path = sanitize_name(path)
		local full_path
		if is_remote then
			full_path = base_dir .. "/Remotes/" .. service_name .. "/" .. path .. ".remote.lua"
		else
			full_path = base_dir .. "/" .. service_name .. "/" .. path .. ".lua"
		end
		make_dir(full_path:match("(.+)/[^/]+$"))
		local ok, err = pcall(writefile, full_path, source)
		if not ok then warn("-- failed to write " .. path .. ": " .. err) end
	end
end
