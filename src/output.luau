local function mkdir(path)
	local cur = ""
	for p in path:gmatch("[^/]+") do
		cur = cur ~= "" and cur.."/"..p or p
		if not isfolder(cur) then makefolder(cur) end
	end
end

return function(result, game_name)
	game_name = game_name:gsub('[*?"<>|]', "_"):gsub(":", "_")
	local base = game_name.."/"..os.date("%H-%M-%S")
	mkdir("_GetMapSrc/" .. base)
	for service, files in next, result do
		for path, src in next, files do
			local full = base.."/"..service.."/"..path..".lua"
			mkdir(full:match("(.+)/[^/]+$"))
			local ok, err = pcall(writefile, full, src)
			if not ok then warn("-- failed: "..err) else print("-- saved: "..full) end
		end
	end
end
