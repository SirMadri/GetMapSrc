return function(service)
	local remotes = {}
	for _, object in next, service:GetDescendants() do
		if object:IsA("RemoteEvent") or object:IsA("RemoteFunction") or object:IsA("UnreliableRemoteEvent") then
			local path = object:GetFullName():gsub("^" .. service.Name .. "%.", ""):gsub("%.", "/"):gsub('[*?"<>|]', "_"):gsub(":", "_")
			remotes[path] = {
				Name = object.Name,
				ClassName = object.ClassName,
				FullName = object:GetFullName(),
			}
		end
	end

	return remotes
end
