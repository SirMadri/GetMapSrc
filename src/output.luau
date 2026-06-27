local function sanitize_name(s)
	s = s:gsub("[\128-\255]+", ""):gsub('%c', '_')
	s = s:gsub('[\\*?"<>|%[%]]', "_"):gsub(":", "_")
	s = s:gsub("//+", "/"):gsub("/+$", "")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

local created_dirs = {}

local function make_dir(path)
	local current = ""
	for segment in path:gmatch("[^/]+") do
		current = current ~= "" and current .. "/" .. segment or segment
		if not created_dirs[current] then
			pcall(makefolder, current)
			created_dirs[current] = true
		end
	end
end

return function(game_name)
	game_name = sanitize_name(game_name):sub(1, 25):gsub("%s+$", "")
	local base_dir = "_GetMapSrc/" .. game_name
	make_dir(base_dir)
	print("-- output dir: " .. base_dir)

	local MAX_DEPTH = 20

	local function write_file(service_name, path, source, is_remote, is_script)
		service_name = sanitize_name(service_name)
		path = sanitize_name(path)
		local full_path
		if is_remote then
			full_path = base_dir .. "/Remotes/" .. service_name .. "/" .. path .. ".remote.lua"
		elseif is_script then
			local script_name = path:match("[^/]+$") or path
			full_path = base_dir .. "/" .. service_name .. "/" .. path .. "/" .. script_name .. ".lua"
		else
			full_path = base_dir .. "/" .. service_name .. "/" .. path .. ".lua"
		end
		local _, depth = full_path:gsub("/", "")
		if depth > MAX_DEPTH or #full_path > 200 then return end
		make_dir(full_path:match("(.+)/[^/]+$"))
		local ok, err = pcall(writefile, full_path, source)
		if not ok then warn("-- failed to write " .. path .. ": " .. err) end
	end

	local function write_root(filename, source)
		local ok, err = pcall(writefile, base_dir .. "/" .. filename, source)
		if not ok then warn("-- failed to write " .. filename .. ": " .. err) end
	end

	return write_file, write_root
end
