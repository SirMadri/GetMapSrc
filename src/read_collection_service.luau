local cs = game:GetService("CollectionService")

return function(max_per_tag)
	local result = {}

	local ok, all_tags = pcall(cs.GetAllTags, cs)
	if not ok then return result end

	for _, tag in next, all_tags do
		local ok2, tagged = pcall(cs.GetTagged, cs, tag)
		if not ok2 or #tagged == 0 then continue end

		local total = #tagged
		local limit = max_per_tag and math.min(total, max_per_tag) or total
		local paths = {}

		for i = 1, limit do
			local ok3, full_name = pcall(function() return tagged[i]:GetFullName() end)
			paths[i] = ok3 and full_name or "?"
		end

		result[tag] = { paths = paths, total = total, truncated = total > limit }
	end

	return result
end
