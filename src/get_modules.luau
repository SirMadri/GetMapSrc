local base_url = "https://raw.githubusercontent.com/SirMadri/GetMapSrc/refs/heads/main/src"
local repo = {}
local pending = 10

for module_name, file_path in next, {
	unc                      = "/UNC.luau",
	blocked_modules          = "/blocked_modules.luau",
	script_src               = "/script_src.luau",
	read_game                = "/read_game.luau",
	read_nil_instances       = "/read_nil_instances.luau",
	read_collection_service  = "/read_collection_service.luau",
	remote_src               = "/remote_src.luau",
	value_src                = "/value_src.luau",
	instance_meta            = "/instance_meta.luau",
	output                   = "/output.luau",
} do
	task.spawn(function()
		repo[module_name] = loadstring(game:HttpGet(base_url .. file_path))()
		pending -= 1
	end)
end

repeat task.wait() until pending == 0
return repo
