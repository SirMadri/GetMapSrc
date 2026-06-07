return function(service)
	local t = {}
	for _, v in next, service:GetDescendants() do
		if v:IsA("ModuleScript") or v:IsA("Script") then
			t[v:GetFullName():gsub("^"..service.Name.."%.", ""):gsub("%.", "/")] = v
		end
	end
	return t
end
