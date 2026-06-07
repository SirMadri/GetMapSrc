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

local ok, info = pcall(mkt.GetProductInfo, mkt, game.PlaceId)
local game_name = ok and info and info.Name or tostring(game.PlaceId)

print("-- dumping: " .. game_name)
print("-- your game may freeze while we look for scripts")

local repo = loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/GetMapSrc/refs/heads/main/src/get_modules.luau"))()
local result = {}
local remotes = {}

-- collect remotes (fast, no HTTP)
if config.dump_remotes then
	for _, service in ipairs(config.services) do
		local found = repo.read_remotes(service)
		if next(found) then
			remotes[service.Name] = {}
			for path, meta in next, found do
				remotes[service.Name][path] = repo.remote_src(meta)
			end
		end
	end
end

-- decompile scripts
if config.use_threading then
	local queue = {}
	for _, service in ipairs(config.services) do
		print("-- reading: " .. service.Name)
		result[service.Name] = {}
		for path, mod in next, repo.read_game(service) do
			queue[#queue + 1] = { svc = service.Name, path = path, mod = mod }
		end
	end

	print("-- spawning " .. #queue .. " threads")
	local done = 0
	for _, entry in next, queue do
		task.spawn(function()
			print("-- decompiling: " .. entry.path)
			result[entry.svc][entry.path] = repo.script_src(entry.mod)
			done += 1
		end)
	end

	repeat task.wait() until done >= #queue
else
	for _, service in ipairs(config.services) do
		print("-- reading: " .. service.Name)
		result[service.Name] = {}
		for path, mod in next, repo.read_game(service) do
			print("-- decompiling: " .. path)
			result[service.Name][path] = repo.script_src(mod)
		end
	end
end

repo.output(result, remotes, game_name)
print("-- done in " .. math.floor((os.clock() - start) * 100) / 100 .. "s")
