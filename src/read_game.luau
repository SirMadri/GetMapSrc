return function(service)
	local scripts, remotes = {}, {}
	for _, v in next, service:GetDescendants() do
		local path = v:GetFullName():gsub("^"..service.Name.."%.", ""):gsub("%.", "/")
		path = path:gsub('%c', '_'):gsub('[*?"<>|\\]', "_"):gsub(":", "_"):gsub("//+", "/"):gsub("/+$", "")
		if v:IsA("ModuleScript") or v:IsA("Script") then
			scripts[path] = v
		elseif v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("UnreliableRemoteEvent") then
			remotes[path] = { Name = v.Name, ClassName = v.ClassName, FullName = v:GetFullName() }
		end
	end
	return scripts, remotes
end
