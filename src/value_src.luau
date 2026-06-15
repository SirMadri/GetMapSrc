local function format_value(v)
	local t = typeof(v)
	if t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "Vector3" then
		return ("{ x = %g, y = %g, z = %g }"):format(v.X, v.Y, v.Z)
	elseif t == "Color3" then
		return ("{%d, %d, %d}"):format(
			math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif t == "CFrame" then
		local p = v.Position
		local rx, ry, rz = v:ToEulerAnglesXYZ()
		return ("{ position = { x = %g, y = %g, z = %g }, orientation = { x = %g, y = %g, z = %g } }"):format(
			p.X, p.Y, p.Z, math.deg(rx), math.deg(ry), math.deg(rz))
	elseif t == "Instance" then
		return '"' .. v:GetFullName() .. '"'
	end
	return "nil"
end

return function(service_name, values)
	local count = 0
	for _ in next, values do count += 1 end

	local lines = {
		"-- GetMapSrc | Value Objects",
		('-- service: "%s"'):format(service_name),
		"-- count: " .. count,
		"",
		"return {",
	}

	for path, data in next, values do
		lines[#lines + 1] = ('\t["%s"] = { class_name = "%s", value = %s },')
			:format(path, data.class_name, format_value(data.value))
	end

	lines[#lines + 1] = "}"
	return table.concat(lines, "\n")
end
