return function(service)
	local t = {}
	for _, v in next, service:GetDescendants() do
		if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("UnreliableRemoteEvent") then
			local path = v:GetFullName():gsub("^"..service.Name.."%.", ""):gsub("%.", "/")
			t[path:gsub('[*?"<>|]', "_"):gsub(":", "_")] = {
				Name = v.Name,
				ClassName = v.ClassName,
				FullName = v:GetFullName(),
			}
		end
	end
	return t
end
