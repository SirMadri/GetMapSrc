return function(meta)
	return table.concat({
		"-- GetMapSrc | Made by SirMari",
		"-- Name: " .. meta.Name,
		"-- ClassName: " .. meta.ClassName,
		"-- FullName: " .. meta.FullName,
		"",
		"return {",
		'\tName = "' .. meta.Name .. '",',
		'\tClassName = "' .. meta.ClassName .. '",',
		'\tFullName = "' .. meta.FullName .. '",',
		"}",
	}, "\n")
end
