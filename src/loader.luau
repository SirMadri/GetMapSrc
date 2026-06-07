repeat task.wait() until game:IsLoaded()
print("-- starting dumper")
print("-- made by SirMadri, https://github.com/SirMadri/MapSrcDumper")

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

local repo = loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/MapSrcDumper/main/src/get_modules.luau"))()
local result = {}

for _, service in ipairs(config.services) do
	print("-- reading: " .. service.Name)
	result[service.Name] = {}
	for path, mod in next, repo.read_game(service) do
		print("-- decompiling: " .. path)
		result[service.Name][path] = repo.script_src(mod)
	end
end

repo.output(result, game_name)
print("-- done in " .. math.floor((os.clock() - start) * 100) / 100 .. "s")
