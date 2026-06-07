return function(service)
	local t = {}
	for _, v in next, service:GetDescendants() do
		if v:IsA("ModuleScript") or v:IsA("Script") then
			local path = v:GetFullName():gsub("^"..service.Name.."%.", ""):gsub("%.", "/")
			t[path:gsub('[*?"<>|]', "_"):gsub(":", "_")] = v
		end
	end
	return t
end
