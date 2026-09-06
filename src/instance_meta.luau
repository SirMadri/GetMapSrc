local cs = game:GetService("CollectionService")

local PROPS = {
	"Archivable",
	-- BasePart
	"Anchored", "CanCollide", "CanTouch", "CanQuery",
	"Transparency", "Reflectance", "Material", "Color",
	"Shape", "CastShadow", "Massless", "Locked",
	"Size", "Position", "Orientation",
	-- Model
	"PrimaryPart", "WorldPivot",
	-- Humanoid
	"Health", "MaxHealth", "WalkSpeed", "JumpPower", "HipHeight",
	-- Light / Sound
	"Brightness", "Range",
	"SoundId", "Volume", "Looped", "Playing",
	-- GuiObject (Position/Size reused above, format_value distinguishes UDim2 vs Vector3)
	"BackgroundColor3", "BackgroundTransparency",
	"BorderColor3", "BorderSizePixel",
	"AnchorPoint", "ZIndex", "LayoutOrder", "Rotation",
	"ClipsDescendants", "AutomaticSize",
	-- Text
	"Text", "TextColor3", "TextTransparency", "TextSize",
	"TextWrapped", "TextXAlignment", "TextYAlignment", "Font",
	-- Image
	"Image", "ImageColor3", "ImageTransparency", "ScaleType",
	-- ScrollingFrame
	"ScrollingEnabled", "CanvasSize",
	-- UI modifiers (UIListLayout, UIPadding, etc.)
	"FillDirection", "HorizontalAlignment", "VerticalAlignment",
	"Padding", "SortOrder",
	-- Misc
	"Visible", "Enabled",
}

local function to_snake_case(s)
	return s:gsub("(%l)(%u)", "%1_%2"):gsub("(%u+)(%u%l)", "%1_%2"):lower()
end

local function format_value(v)
	local t = typeof(v)
	if t == "Vector3" then
		return ("{ x = %g, y = %g, z = %g }"):format(v.X, v.Y, v.Z)
	elseif t == "Vector2" then
		return ("{ x = %g, y = %g }"):format(v.X, v.Y)
	elseif t == "UDim2" then
		return ("{ x = { scale = %g, offset = %d }, y = { scale = %g, offset = %d } }"):format(
			v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
	elseif t == "UDim" then
		return ("{ scale = %g, offset = %d }"):format(v.Scale, v.Offset)
	elseif t == "Color3" then
		return ("{%d, %d, %d}"):format(
			math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif t == "CFrame" then
		local p = v.Position
		local rx, ry, rz = v:ToEulerAnglesXYZ()
		return ("{ position = { x = %g, y = %g, z = %g }, orientation = { x = %g, y = %g, z = %g } }"):format(
			p.X, p.Y, p.Z, math.deg(rx), math.deg(ry), math.deg(rz))
	elseif t == "EnumItem" then
		return '"' .. v.Name .. '"'
	elseif t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
	elseif t == "boolean" or t == "number" then
		return tostring(v)
	elseif t == "Instance" then
		return '"' .. v:GetFullName() .. '"'
	end
	return nil
end

-- descendant_count is supplied by read_game, which derives every count in one
-- upward pass; calling obj:GetDescendants() per instance here was quadratic and
-- dominated the cost of dumping a large Workspace
return function(obj, descendant_count)
	local lines = {
		"return {",
		('\tname = "%s",'):format(obj.Name),
		('\tclass_name = "%s",'):format(obj.ClassName),
		"",
	}

	-- properties
	local has_props = false
	local prop_lines = {}
	for _, name in next, PROPS do
		local ok, val = pcall(function() return obj[name] end)
		if ok and val ~= nil then
			local fv = format_value(val)
			if fv then
				prop_lines[#prop_lines + 1] = "\t\t" .. to_snake_case(name) .. " = " .. fv .. ","
				has_props = true
			end
		end
	end
	if has_props then
		lines[#lines + 1] = "\tproperties = {"
		for _, l in next, prop_lines do lines[#lines + 1] = l end
		lines[#lines + 1] = "\t},"
		lines[#lines + 1] = ""
	end

	-- attributes
	local ok_attr, attrs = pcall(obj.GetAttributes, obj)
	if ok_attr and next(attrs) then
		lines[#lines + 1] = "\tattributes = {"
		for k, v in next, attrs do
			local fv = format_value(v)
			if fv then lines[#lines + 1] = "\t\t" .. to_snake_case(k) .. " = " .. fv .. "," end
		end
		lines[#lines + 1] = "\t},"
		lines[#lines + 1] = ""
	end

	-- tags
	local ok_tags, tags = pcall(cs.GetTags, cs, obj)
	if ok_tags and #tags > 0 then
		lines[#lines + 1] = "\ttags = {"
		for _, tag in next, tags do
			lines[#lines + 1] = '\t\t"' .. tag .. '",'
		end
		lines[#lines + 1] = "\t},"
		lines[#lines + 1] = ""
	end

	-- references
	local parent_path = obj.Parent and obj.Parent:GetFullName() or "nil"
	lines[#lines + 1] = "\treferences = {"
	lines[#lines + 1] = '\t\tparent = "' .. parent_path .. '",'
	lines[#lines + 1] = "\t},"
	lines[#lines + 1] = ""

	-- statistics
	local _, chld_list = pcall(obj.GetChildren, obj)
	local chld_count = type(chld_list) == "table" and #chld_list or 0
	local desc_count = descendant_count
	if desc_count == nil then
		local _, desc_list = pcall(obj.GetDescendants, obj)
		desc_count = type(desc_list) == "table" and #desc_list or 0
	end
	lines[#lines + 1] = "\tstatistics = {"
	lines[#lines + 1] = "\t\tdescendants = " .. desc_count .. ","
	lines[#lines + 1] = "\t\tchildren = " .. chld_count .. ","
	lines[#lines + 1] = "\t},"

	-- children names (reusing the list already fetched for statistics)
	local children = type(chld_list) == "table" and chld_list or {}
	if #children > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "\tchildren = {"
		for _, child in next, children do
			lines[#lines + 1] = '\t\t"' .. child.Name .. '",'
		end
		lines[#lines + 1] = "\t},"
	end

	lines[#lines + 1] = "}"
	return table.concat(lines, "\n")
end
