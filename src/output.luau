-- executor functions live in the lexical global scope on some executors and in
-- getgenv() on others; resolve both so UNC.luau and this module agree
local genv = getgenv()

local function pick(lexical, name)
	if lexical ~= nil then return lexical end
	local ok, value = pcall(rawget, genv, name)
	if ok and value ~= nil then return value end
	return nil
end

local fn_makefolder = pick(makefolder, "makefolder")
local fn_writefile = pick(writefile, "writefile")

local function sanitize_name(s)
	s = s:gsub("[\128-\255]+", ""):gsub('%c', '_')
	s = s:gsub('[\*?"<>|%[%]]', "_"):gsub(":", "_")
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
			pcall(fn_makefolder, current)
			created_dirs[current] = true
		end
	end
end

-- keep the reported list bounded; the total is counted separately
local MAX_REPORTED_SKIPS = 200

return function(game_name)
	game_name = sanitize_name(game_name):sub(1, 25):gsub("%s+$", "")
	local base_dir = "_GetMapSrc/" .. game_name
	make_dir(base_dir)
	print("-- output dir: " .. base_dir)

	local MAX_DEPTH = 20
	local MAX_PATH = 200

	local skipped = {}
	local skipped_total = 0

	local function record_skip(full_path, reason)
		skipped_total += 1
		if #skipped < MAX_REPORTED_SKIPS then
			skipped[#skipped + 1] = full_path .. " (" .. reason .. ")"
		end
	end

	local function resolve_path(service_name, path, is_remote, is_script)
		service_name = sanitize_name(service_name)
		path = sanitize_name(path)
		if is_remote then
			return base_dir .. "/Remotes/" .. service_name .. "/" .. path .. ".remote.lua"
		end
		if is_script then
			local script_name = path:match("[^/]+$") or path
			return base_dir .. "/" .. service_name .. "/" .. path .. "/" .. script_name .. ".lua"
		end
		return base_dir .. "/" .. service_name .. "/" .. path .. ".lua"
	end

	-- files dropped for depth or length used to vanish with no trace; they are
	-- recorded now so _dump_info can report what is missing from the dump
	local function write_file(service_name, path, source, is_remote, is_script)
		local full_path = resolve_path(service_name, path, is_remote, is_script)

		local _, depth = full_path:gsub("/", "")
		if depth > MAX_DEPTH then
			record_skip(full_path, "depth " .. depth .. " > " .. MAX_DEPTH)
			return false
		end
		if #full_path > MAX_PATH then
			record_skip(full_path, #full_path .. " chars > " .. MAX_PATH)
			return false
		end

		make_dir(full_path:match("(.+)/[^/]+$"))
		local ok, err = pcall(fn_writefile, full_path, source)
		if not ok then
			warn("-- failed to write " .. path .. ": " .. tostring(err))
			record_skip(full_path, "write error: " .. tostring(err))
			return false
		end
		return true
	end

	local function write_root(filename, source)
		local ok, err = pcall(fn_writefile, base_dir .. "/" .. filename, source)
		if not ok then
			warn("-- failed to write " .. filename .. ": " .. tostring(err))
			return false
		end
		return true
	end

	return {
		base_dir = base_dir,
		write_file = write_file,
		write_root = write_root,
		resolve_path = resolve_path,
		get_skipped = function() return skipped, skipped_total end,
	}
end
