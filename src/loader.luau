repeat task.wait() until game:IsLoaded()
print("-- starting dumper")
print("-- made by SirMadri, https://github.com/SirMadri/GetMapSrc")

local marketplace = cloneref and cloneref(game:GetService("MarketplaceService")) or game:GetService("MarketplaceService")
local start_time = os.clock()
local config = getgenv().dumper or {}

local VERSION = "1.0.1"; print("-- " .. VERSION)

config.services = config.services or {
	game:GetService("ReplicatedStorage"),
	game:GetService("ReplicatedFirst"),
	game:GetService("StarterPlayer"),
	game:GetService("StarterGui"),
	game:GetService("Workspace"),
	game:GetService("Players").LocalPlayer.PlayerGui,
}

local info_ok, game_info = pcall(marketplace.GetProductInfoAsync, marketplace, game.PlaceId)
local game_name = info_ok and game_info and game_info.Name or tostring(game.PlaceId)

print("-- dumping: " .. game_name)
print("-- your game may freeze while we look for scripts")

local repo = loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/GetMapSrc/refs/heads/main/src/get_modules.luau"))()
local caps = repo.unc

if not caps.can_decompile then
	warn("-- missing getscriptbytecode or request - decompilation will not work")
end
if not caps.can_write then
	error("-- missing filesystem functions (isfolder/makefolder/writefile) - cannot save output")
end

local queue = {}
local write_file, write_root = repo.output(game_name)
local TIMEOUT = 60

local total_remotes, total_bindables, total_values, nil_script_count = 0, 0, 0, 0
local failed_scripts = {}

local dump_map = config.dump_map ~= false
local map_services = config.map_services

for _, service in ipairs(config.services) do
	local svc_name = service.ClassName
	print("-- reading: " .. svc_name)
	local should_map = dump_map and (map_services == nil or map_services[svc_name])
	local scripts, found_remotes, meta_instances, values, bindables = repo.read_game(service, should_map)

	for path, mod in next, scripts do
		queue[#queue + 1] = { service = svc_name, path = path, mod = mod }
	end

	if config.dump_remotes ~= false then
		local ri = 0
		for path, meta in next, found_remotes do
			ri += 1
			if ri % 50 == 0 then task.wait() end
			write_file(svc_name, path, repo.remote_src(meta), true)
		end
		total_remotes += ri
	end

	if config.dump_bindables ~= false then
		local bi = 0
		for path, meta in next, bindables do
			bi += 1
			if bi % 50 == 0 then task.wait() end
			write_file("_Bindables/" .. svc_name, path, repo.remote_src(meta))
		end
		total_bindables += bi
	end

	if config.dump_values ~= false and next(values) then
		local vc = 0
		for _ in next, values do vc += 1 end
		total_values += vc
		write_file("_Values", svc_name, repo.value_src(svc_name, values))
	end

	if should_map then
		local mi = 0
		for path, obj in next, meta_instances do
			mi += 1
			if mi % 50 == 0 then task.wait() end
			local ok, src = pcall(repo.instance_meta, obj)
			if ok then write_file(svc_name, path .. "/_meta", src) end
		end
	end
end

local tag_count = 0
if config.dump_collection ~= false then
	print("-- reading: collection service")
	local max_per_tag = config.collection_max_per_tag or 500
	local tags = repo.read_collection_service(max_per_tag)

	for tag, data in next, tags do
		local lines = {
			"-- GetMapSrc | CollectionService",
			('-- tag: "%s"'):format(tag),
			"-- total: " .. data.total .. (data.truncated and (" (showing " .. #data.paths .. ")") or ""),
			"",
			"return {",
		}
		for _, path in next, data.paths do
			lines[#lines + 1] = '\t"' .. path .. '",'
		end
		if data.truncated then
			lines[#lines + 1] = "\t-- (" .. (data.total - #data.paths) .. " more truncated)"
		end
		lines[#lines + 1] = "}"

		local safe_tag = tag:gsub("[\128-\255]+", ""):gsub('[\\/*?"<>|%c]', "_"):gsub(":", "_")
		write_file("_CollectionService", safe_tag, table.concat(lines, "\n"))
		tag_count += 1
	end

	print("-- " .. tag_count .. " tags dumped")
end

if caps.getnilinstances and config.dump_nil_instances ~= false then
	print("-- reading: nil instances")
	local nil_scripts, nil_remotes = repo.read_nil_instances()

	for path, mod in next, nil_scripts do
		nil_script_count += 1
		queue[#queue + 1] = { service = "nilinstances", path = path, mod = mod }
	end

	if config.dump_remotes ~= false then
		for path, meta in next, nil_remotes do
			write_file("nilinstances", path, repo.remote_src(meta), true)
		end
	end
end

print("-- " .. #queue .. " scripts queued")

local function decompile_entry(entry)
	local success, source = pcall(repo.script_src, entry.mod)
	if not success then
		failed_scripts[#failed_scripts + 1] = entry.service .. "/" .. entry.path
		return "-- error: " .. tostring(source)
	end
	return source
end

if config.use_threading == false then
	for _, entry in next, queue do
		print("-- decompiling: " .. entry.path)
		local source = decompile_entry(entry)
		if source then
			write_file(entry.service, entry.path, source, nil, true)
		end
	end
else
	local MAX_WORKERS = 25
	print("-- workers: " .. MAX_WORKERS .. ", timeout: " .. TIMEOUT .. "s each")
	local active_workers = 0
	local done_count = 0

	for _, entry in next, queue do
		repeat task.wait() until active_workers < MAX_WORKERS
		active_workers += 1

		task.spawn(function()
			local timed_out = false

			task.delay(TIMEOUT, function()
				if timed_out then return end
				timed_out = true
				warn("-- timeout (" .. TIMEOUT .. "s): " .. entry.path)
				failed_scripts[#failed_scripts + 1] = entry.service .. "/" .. entry.path .. " (timeout)"
				write_file(entry.service, entry.path, "-- decompilation timed out after " .. TIMEOUT .. "s", nil, true)
				active_workers -= 1
				done_count += 1
			end)

			local source = decompile_entry(entry)
			if timed_out then return end
			timed_out = true

			done_count += 1
			if source then
				print("-- [" .. done_count .. "/" .. #queue .. "] " .. entry.path)
				write_file(entry.service, entry.path, source, nil, true)
			end
			active_workers -= 1
		end)
	end

	repeat task.wait() until done_count >= #queue
end

local elapsed = math.floor((os.clock() - start_time) * 100) / 100
print("-- done in " .. elapsed .. "s")

local local_player = game:GetService("Players").LocalPlayer
local function esc(s) return tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') end

local scanned_names = {}
for _, svc in ipairs(config.services) do
	scanned_names[#scanned_names + 1] = '"' .. esc(svc.Name or svc.ClassName) .. '"'
end

local info_lines = {
	"-- GetMapSrc | Dump Info",
	"return {",
	('\tgame_name = "%s",'):format(esc(game_name)),
	("\tplace_id = %d,"):format(game.PlaceId),
	('\tjob_id = "%s",'):format(esc(game.JobId)),
	('\tdump_date = "%s",'):format(os.date("%Y-%m-%d %H:%M:%S")),
	("\telapsed_seconds = %g,"):format(elapsed),
	"\tplayer = {",
	('\t\tname = "%s",'):format(esc(local_player.Name)),
	("\t\tuser_id = %d,"):format(local_player.UserId),
	"\t},",
	"\tservices_scanned = { " .. table.concat(scanned_names, ", ") .. " },",
	"\tcounts = {",
	("\t\tscripts = %d,"):format(#queue),
	("\t\tremotes = %d,"):format(total_remotes),
	("\t\tbindables = %d,"):format(total_bindables),
	("\t\tvalues = %d,"):format(total_values),
	("\t\tcollection_tags = %d,"):format(tag_count),
	("\t\tnil_scripts = %d,"):format(nil_script_count),
	"\t},",
}

if #failed_scripts > 0 then
	info_lines[#info_lines + 1] = "\tfailed_scripts = {"
	for _, path in ipairs(failed_scripts) do
		info_lines[#info_lines + 1] = ('\t\t"%s",'):format(esc(path))
	end
	info_lines[#info_lines + 1] = "\t},"
end

info_lines[#info_lines + 1] = "}"
write_root("_dump_info.lua", table.concat(info_lines, "\n"))
