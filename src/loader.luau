repeat task.wait() until game:IsLoaded()
print("-- starting dumper")
print("-- made by SirMadri, https://github.com/SirMadri/GetMapSrc")

-- UNC.luau installs the cloneref fallback, but it only loads further down, so
-- this call has to tolerate a missing cloneref on its own
local clone_ref = cloneref or function(ref) return ref end
local marketplace = clone_ref(game:GetService("MarketplaceService"))
local start_time = os.clock()
local config = getgenv().dumper or {}

local executor = identifyexecutor() or "shit executor"

local VERSION = "1.3.0"; print("-- " .. VERSION)

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

print("-- executor: " .. executor)
print("-- dumping: " .. game_name)
print("-- your game may freeze while we look for scripts")

local repo = loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/GetMapSrc/refs/heads/main/src/get_modules.luau"))()
local caps = repo.unc

local function normalize_decompiler(value)
	local method = tostring(value or "auto"):lower():gsub("%s+", "")
	if method == "" or method == "auto" then
		return "auto"
	end
	if method == "executor" or method == "native" or method == "decompile" then
		return "executor"
	end
	if method == "luaexpert" or method == "lua.expert" or method == "lua_expert" or method == "api" then
		return "luaexpert"
	end
	return method
end

local decompiler_mode = normalize_decompiler(config.decompiler)
if decompiler_mode ~= "auto" and decompiler_mode ~= "executor" and decompiler_mode ~= "luaexpert" then
	warn("-- unknown decompiler '" .. tostring(config.decompiler) .. "', using auto")
	decompiler_mode = "auto"
end

local selected_can_decompile = caps.can_decompile
if decompiler_mode == "executor" then
	selected_can_decompile = caps.decompile
elseif decompiler_mode == "luaexpert" then
	selected_can_decompile = caps.can_luaexpert
end

if decompiler_mode == "auto" then
	if caps.decompile then
		print("-- decompiler: executor decompile()")
	elseif caps.can_luaexpert then
		warn("-- no executor decompile(), using luaexpert fallback")
	else
		warn("-- no supported decompiler found")
	end
elseif decompiler_mode == "executor" then
	print("-- decompiler: executor decompile()")
elseif decompiler_mode == "luaexpert" then
	print("-- decompiler: luaexpert")
end

if not selected_can_decompile then
	warn("-- selected decompiler is unavailable - decompilation will not work")
end
if not caps.can_write then
	error("-- missing filesystem functions (isfolder/makefolder/writefile) - cannot save output")
end

local queue = {}
local out = repo.output(game_name)
local write_file, write_root = out.write_file, out.write_root
local TIMEOUT = 60

-- blocked modules are marked collected too, otherwise the nil scan would
-- rediscover them under a different path and defeat the block
local collected = {}

local function queue_script(service, path, mod)
	if collected[mod] then return end
	collected[mod] = true

	if repo.blocked_modules(game.PlaceId, path) then
		warn("-- skipping known crashing module: " .. service .. "/" .. path)
		return
	end

	queue[#queue + 1] = { service = service, path = path, mod = mod }
end

local total_remotes, total_bindables, total_values, nil_script_count = 0, 0, 0, 0
local cached_script_count, duplicate_count, resumed_count = 0, 0, 0
local failed_scripts = {}

local dump_map = config.dump_map ~= false
local map_services = config.map_services

for _, service in ipairs(config.services) do
	local svc_name = service.ClassName
	print("-- reading: " .. svc_name)
	local should_map = dump_map and (map_services == nil or map_services[svc_name])
	local scripts, found_remotes, meta_instances, values, bindables, descendant_counts = repo.read_game(service, should_map)

	for path, mod in next, scripts do
		queue_script(svc_name, path, mod)
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
			local ok, src = pcall(repo.instance_meta, obj, descendant_counts[obj] or 0)
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

-- read_nil_instances also mines getmodules(), so either capability is enough
if (caps.getnilinstances or caps.getmodules) and config.dump_nil_instances ~= false then
	print("-- reading: nil instances")
	local nil_scripts, nil_remotes, cached_scripts = repo.read_nil_instances(collected)

	for path, mod in next, nil_scripts do
		nil_script_count += 1
		queue_script("nilinstances", path, mod)
	end

	-- cached modules that still have a parent live in a real (but unscanned)
	-- container, so filing them under nilinstances/ would be misleading
	for path, mod in next, cached_scripts do
		cached_script_count += 1
		queue_script("_CachedModules", path, mod)
	end

	if config.dump_remotes ~= false then
		for path, meta in next, nil_remotes do
			write_file("nilinstances", path, repo.remote_src(meta), true)
		end
	end
end

local total_queued = #queue
print("-- " .. total_queued .. " scripts queued")

local function entry_key(entry)
	return entry.service .. "/" .. entry.path
end

-- resume
--
-- a crashed dump leaves a progress file behind listing what was written, so a
-- restart skips that work instead of redoing the whole game. only successes are
-- recorded, so timeouts and errors are retried on the next run.
local resume_enabled = config.resume ~= false and caps.can_resume
local progress_file = out.base_dir .. "/_progress.txt"
local progress_lines, progress_done, progress_buffer = {}, {}, {}

if resume_enabled then
	local read_ok, content = pcall(caps.fn.readfile, progress_file)
	if read_ok and type(content) == "string" then
		for line in content:gmatch("[^\r\n]+") do
			if not progress_done[line] then
				progress_done[line] = true
				progress_lines[#progress_lines + 1] = line
			end
		end
	end
end

local function flush_progress()
	if not resume_enabled or #progress_buffer == 0 then return end
	local batch = table.concat(progress_buffer, "\n") .. "\n"
	table.clear(progress_buffer)
	if caps.appendfile then
		pcall(caps.fn.appendfile, progress_file, batch)
	else
		pcall(caps.fn.writefile, progress_file, table.concat(progress_lines, "\n") .. "\n")
	end
end

local function mark_done(key)
	if not resume_enabled or progress_done[key] then return end
	progress_done[key] = true
	progress_lines[#progress_lines + 1] = key
	progress_buffer[#progress_buffer + 1] = key
	if #progress_buffer >= 25 then flush_progress() end
end

if resume_enabled and next(progress_done) then
	local remaining = {}
	for _, entry in next, queue do
		if progress_done[entry_key(entry)] then
			resumed_count += 1
		else
			remaining[#remaining + 1] = entry
		end
	end
	queue = remaining
	print("-- resuming: " .. resumed_count .. " scripts already dumped, " .. #queue .. " left")
end

-- bytecode dedup
--
-- games repeat the same module dozens of times; identical bytecode is
-- decompiled once and the copies reuse that body under their own header
if caps.can_dedupe and config.dedupe_scripts ~= false then
	local by_hash, unique = {}, {}
	for index, entry in next, queue do
		if index % 200 == 0 then task.wait() end
		local hash_ok, hash = pcall(caps.fn.getscripthash, entry.mod)
		if hash_ok and type(hash) == "string" and hash ~= "" then
			local representative = by_hash[hash]
			if representative then
				representative.aliases = representative.aliases or {}
				representative.aliases[#representative.aliases + 1] = entry
				duplicate_count += 1
				continue
			end
			by_hash[hash] = entry
		end
		unique[#unique + 1] = entry
	end
	queue = unique
	if duplicate_count > 0 then
		print("-- " .. duplicate_count .. " duplicates share bytecode, decompiling " .. #queue .. " unique scripts")
	end
end

local function decompile_entry(entry)
	local success, source, detail, body = pcall(repo.script_src, entry.mod, {
		decompiler = decompiler_mode,
	})
	if not success then
		failed_scripts[#failed_scripts + 1] = entry_key(entry)
		return "-- error: " .. tostring(source)
	end
	if not source then
		failed_scripts[#failed_scripts + 1] = entry_key(entry)
		return "-- decompilation failed\n--[[\n" .. tostring(detail or "unknown error") .. "\n--]]"
	end
	return source, body, detail
end

-- body is the source without its header; a duplicate gets a header naming the
-- script the file actually came from instead of the one that was decompiled
local function write_entry(entry, source, body, decompiler_name)
	local succeeded = body ~= nil

	if write_file(entry.service, entry.path, source, nil, true) and succeeded then
		mark_done(entry_key(entry))
	end

	if not entry.aliases then return end
	for _, alias in next, entry.aliases do
		local alias_source = source
		if succeeded then
			local header_ok, header = pcall(repo.script_src.header, alias.mod, decompiler_name)
			if header_ok then alias_source = header .. body end
		end
		if write_file(alias.service, alias.path, alias_source, nil, true) and succeeded then
			mark_done(entry_key(alias))
		end
	end
end

if config.use_threading == false then
	for _, entry in next, queue do
		print("-- decompiling: " .. entry.path)
		write_entry(entry, decompile_entry(entry))
	end
else
	local MAX_WORKERS = 25
	print("-- workers: " .. MAX_WORKERS .. ", timeout: " .. TIMEOUT .. "s each")
	local active_workers = 0
	local done_count = 0
	local stuck_workers = 0

	for _, entry in next, queue do
		-- a timed-out worker keeps holding its slot until the decompile actually
		-- returns; releasing it early lets real decompiles pile up past MAX_WORKERS
		-- and that is what crashes roblox on heavy games
		repeat task.wait() until active_workers < MAX_WORKERS
		active_workers += 1

		task.spawn(function()
			local resolved = false
			local slot_released = false
			local counted_stuck = false

			local function release_slot()
				if slot_released then return end
				slot_released = true
				if counted_stuck then stuck_workers -= 1 end
				active_workers -= 1
			end

			local timer = task.delay(TIMEOUT, function()
				if resolved then return end
				resolved = true
				counted_stuck = true
				stuck_workers += 1
				warn("-- timeout (" .. TIMEOUT .. "s): " .. entry.path)
				failed_scripts[#failed_scripts + 1] = entry.service .. "/" .. entry.path .. " (timeout)"
				write_entry(entry, "-- decompilation timed out after " .. TIMEOUT .. "s")
				done_count += 1
				if stuck_workers >= MAX_WORKERS // 2 then
					warn("-- " .. stuck_workers .. "/" .. MAX_WORKERS .. " workers stuck, decompiler may be hanging")
				end
				-- grace period for the hung decompile to return on its own; without
				-- it a thread that never returns would stall the queue forever
				task.delay(TIMEOUT * 2, release_slot)
			end)

			local source, body, decompiler_name = decompile_entry(entry)

			if not resolved then
				resolved = true
				task.cancel(timer)
				done_count += 1
				print("-- [" .. done_count .. "/" .. #queue .. "] " .. entry.path)
				write_entry(entry, source, body, decompiler_name)
			end

			release_slot()
		end)
	end

	repeat task.wait() until done_count >= #queue
end

flush_progress()

if resume_enabled then
	-- a clean run clears the checkpoint; a run with failures keeps it so the next
	-- run retries only what failed
	if #failed_scripts == 0 then
		if caps.delfile then
			pcall(caps.fn.delfile, progress_file)
		else
			pcall(caps.fn.writefile, progress_file, "")
		end
	else
		print("-- " .. #failed_scripts .. " scripts failed; rerun to retry just those")
	end
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
	('\texecutor = "%s",'):format(esc(executor)),
	('\tdecompiler = "%s",'):format(esc(decompiler_mode)),
	("\telapsed_seconds = %g,"):format(elapsed),
	"\tplayer = {",
	('\t\tname = "%s",'):format(esc(local_player.Name)),
	("\t\tuser_id = %d,"):format(local_player.UserId),
	"\t},",
	"\tservices_scanned = { " .. table.concat(scanned_names, ", ") .. " },",
	"\tcounts = {",
	("\t\tscripts = %d,"):format(total_queued),
	("\t\tremotes = %d,"):format(total_remotes),
	("\t\tbindables = %d,"):format(total_bindables),
	("\t\tvalues = %d,"):format(total_values),
	("\t\tcollection_tags = %d,"):format(tag_count),
	("\t\tnil_scripts = %d,"):format(nil_script_count),
	("\t\tcached_modules = %d,"):format(cached_script_count),
	("\t\tduplicate_scripts = %d,"):format(duplicate_count),
	("\t\tresumed_scripts = %d,"):format(resumed_count),
	"\t},",
}

local skipped_files, skipped_total = out.get_skipped()
if skipped_total > 0 then
	info_lines[#info_lines + 1] = ("\tskipped_files = %d,"):format(skipped_total)
	info_lines[#info_lines + 1] = "\tskipped_file_paths = {"
	for _, path in ipairs(skipped_files) do
		info_lines[#info_lines + 1] = ('\t\t"%s",'):format(esc(path))
	end
	if skipped_total > #skipped_files then
		info_lines[#info_lines + 1] = ("\t\t-- (%d more not listed)"):format(skipped_total - #skipped_files)
	end
	info_lines[#info_lines + 1] = "\t},"
end

if #failed_scripts > 0 then
	info_lines[#info_lines + 1] = "\tfailed_scripts = {"
	for _, path in ipairs(failed_scripts) do
		info_lines[#info_lines + 1] = ('\t\t"%s",'):format(esc(path))
	end
	info_lines[#info_lines + 1] = "\t},"
end

info_lines[#info_lines + 1] = "}"
write_root("_dump_info.lua", table.concat(info_lines, "\n"))
