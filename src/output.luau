local function mkdir(path)
	local cur = ""
	for p in path:gmatch("[^/]+") do
		cur = cur ~= "" and cur.."/"..p or p
		if not isfolder(cur) then makefolder(cur) end
	end
end

return function(game_name)
	game_name = game_name:gsub('[*?"<>|]', "_"):gsub(":", "_")
	local base = "_GetMapSrc/"..game_name.."/"..os.date("%H-%M-%S")
	mkdir(base)
	print("-- output dir: " .. base)

	return function(svc, path, src, is_remote)
		local full
		if is_remote then
			full = base.."/Remotes/"..svc.."/"..path..".remote.lua"
		else
			full = base.."/"..svc.."/"..path..".lua"
		end
		mkdir(full:match("(.+)/[^/]+$"))
		local ok, err = pcall(writefile, full, src)
		if not ok then warn("-- failed to write "..path..": "..err) end
	end
end
