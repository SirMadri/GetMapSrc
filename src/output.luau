local function sanitize_name(s)
	s = s:gsub("[\128-\255]+", ""):gsub('%c', '_')
	s = s:gsub('[\\*?"<>|%[%]]', "_"):gsub(":", "_")
	s = s:gsub("//+", "/"):gsub("/+$", "")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

local function make_dir(path)
	local current = ""
	for segment in path:gmatch("[^/]+") do
		current = current ~= "" and current .. "/" .. segment or segment
		local ok, err = pcall(makefolder, current)
		if not ok and not isfolder(current) then
			warn("-- mkdir failed at: " .. current .. " | " .. tostring(err))
		end
	end
end

return function(game_name)
	game_name = sanitize_name(game_name):sub(1, 25)
	local base_dir = "_GetMapSrc/" .. game_name
	make_dir(base_dir)
	print("-- output dir: " .. base_dir)

	return function(service_name, path, source, is_remote, is_script)
		service_name = sanitize_name(service_name)
		path = sanitize_name(path)
		local full_path
		if is_remote then
			full_path = base_dir .. "/Remotes/" .. service_name .. "/" .. path .. ".remote.lua"
		elseif is_script then
			full_path = base_dir .. "/" .. service_name .. "/" .. path .. "/_.lua"
		else
			full_path = base_dir .. "/" .. service_name .. "/" .. path .. ".lua"
		end
		make_dir(full_path:match("(.+)/[^/]+$"))
		local ok, err = pcall(writefile, full_path, source)
		if not ok then warn("-- failed to write " .. path .. ": " .. err) end
	end
end
