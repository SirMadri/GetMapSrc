local function sanitize(s)
	return s:gsub('[\\*?"<>|]', "_"):gsub(":", "_")
end

local function mkdir(path)
	local cur = ""
	for p in path:gmatch("[^/]+") do
		cur = cur ~= "" and cur.."/"..p or p
		if not isfolder(cur) then pcall(makefolder, cur) end
	end
end

return function(game_name)
	game_name = sanitize(game_name)
	local base = "_GetMapSrc/"..game_name.."/"..os.date("%H-%M-%S")
	mkdir(base)
	print("-- output dir: " .. base)

	return function(svc, path, src, is_remote)
		svc = sanitize(svc)
		path = sanitize(path)
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
