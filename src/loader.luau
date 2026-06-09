repeat task.wait() until game:IsLoaded()
print("-- starting dumper")
print("-- made by SirMadri, https://github.com/SirMadri/GetMapSrc")

local mkt = cloneref and cloneref(game:GetService("MarketplaceService")) or game:GetService("MarketplaceService")
local start = os.clock()
local config = getgenv().dumper or {}

config.services = config.services or {
	game:GetService("ReplicatedStorage"),
	game:GetService("ReplicatedFirst"),
	game:GetService("StarterPlayer"),
	game:GetService("StarterGui"),
	game:GetService("Workspace"),
}

local ok, info = pcall(mkt.GetProductInfoAsync, mkt, game.PlaceId)
local game_name = ok and info and info.Name or tostring(game.PlaceId)

print("-- dumping: " .. game_name)
print("-- your game may freeze while we look for scripts")

local repo = loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/GetMapSrc/refs/heads/main/src/get_modules.luau"))()
local queue = {}
local write = repo.output(game_name)
local TIMEOUT = config.timeout or 30

for _, service in ipairs(config.services) do
	print("-- reading: " .. service.Name)

	local scripts, found_remotes = repo.read_game(service)

	for path, mod in next, scripts do
		queue[#queue + 1] = { svc = service.Name, path = path, mod = mod }
	end

	if config.dump_remotes ~= false then
		for path, meta in next, found_remotes do
			write(service.Name, path, repo.remote_src(meta), true)
		end
	end
end

print("-- " .. #queue .. " scripts queued")

if config.use_threading == false then
	for _, entry in next, queue do
		print("-- decompiling: " .. entry.path)
		local success, src = pcall(repo.script_src, entry.mod)
		write(entry.svc, entry.path, success and src or ("-- error: " .. tostring(src)))
	end
else
	print("-- spawning " .. #queue .. " threads (timeout: " .. TIMEOUT .. "s each)")
	local done = 0
	for _, entry in next, queue do
		task.spawn(function()
			local completed = false

			task.delay(TIMEOUT, function()
				if not completed then
					completed = true
					warn("-- timeout (" .. TIMEOUT .. "s): " .. entry.path)
					write(entry.svc, entry.path, "-- decompilation timed out after " .. TIMEOUT .. "s")
					done += 1
				end
			end)

			local success, src = pcall(repo.script_src, entry.mod)
			if completed then return end
			completed = true

			src = success and src or ("-- error: " .. tostring(src))
			print("-- decompiled: " .. entry.path)
			write(entry.svc, entry.path, src)
			done += 1
		end)
	end
	repeat task.wait() until done >= #queue
end

print("-- done in " .. math.floor((os.clock() - start) * 100) / 100 .. "s")
