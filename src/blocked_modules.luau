local BLOCKED_MODULES = {
	{
		place_ids = {
			[85211729168715] = true,
			[2753915549] = true,
			[79091703265657] = true,
			[4442272183] = true,
			[7449423635] = true,
			[100117331123089] = true,
		},
		path_suffix = "LeviathanCinematicc/Intro/Enemies/Leviathan/Animations/ModuleScript", -- bloxfruits crash module
	},
}

local function path_matches_suffix(path, suffix)
	return path == suffix or path:sub(-#suffix - 1) == "/" .. suffix
end

return function(place_id, path)
	for _, blocked_module in ipairs(BLOCKED_MODULES) do
		if blocked_module.place_ids[place_id] and path_matches_suffix(path, blocked_module.path_suffix) then
			return true
		end
	end

	return false
end
