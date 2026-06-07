local url = "https://raw.githubusercontent.com/SirMadri/GetMapSrc/refs/heads/main/src"
local repo, n = {}, 5

for k, f in next, {
	script_src    = "/script_src.luau",
	read_game     = "/read_game.luau",
	output        = "/output.luau",
	read_remotes  = "/read_remotes.luau",
	remote_src    = "/remote_src.luau",
} do
	task.spawn(function()
		repo[k] = loadstring(game:HttpGet(url..f))()
		n -= 1
	end)
end

repeat task.wait() until n == 0
return repo
