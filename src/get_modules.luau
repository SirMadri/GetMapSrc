local url = "https://raw.githubusercontent.com/SirMadri/MapSrcDumper/main/src"
local repo, n = {}, 3

for k, f in next, { script_src="/script_src.luau", read_game="/read_game.luau", output="/output.luau" } do
	task.spawn(function()
		repo[k] = loadstring(game:HttpGet(url..f))()
		n -= 1
	end)
end

repeat task.wait() until n == 0
return repo
