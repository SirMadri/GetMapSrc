assert(getscriptbytecode, "exploit does not support getscriptbytecode.")

local last_request_time = 0
local request_lock = false
local http = cloneref and cloneref(game:GetService("HttpService")) or game:GetService("HttpService")
local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function encode_base64(data)
	local result, padding = {}, #data % 3
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i), data:byte(i + 1) or 0, data:byte(i + 2) or 0
		local n = a * 65536 + b * 256 + c
		result[#result + 1] = BASE64_CHARS:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
		result[#result + 1] = BASE64_CHARS:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
		result[#result + 1] = BASE64_CHARS:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
		result[#result + 1] = BASE64_CHARS:sub(n % 64 + 1, n % 64 + 1)
	end
	if padding == 1 then result[#result - 1], result[#result] = "=", "="
	elseif padding == 2 then result[#result] = "=" end
	return table.concat(result)
end

local function wait_rate_limit()
	while request_lock do task.wait() end
	request_lock = true
	local elapsed = os.clock() - last_request_time
	if elapsed < 0.12 then task.wait(0.12 - elapsed) end
	last_request_time = os.clock()
	request_lock = false
end

return function(script_obj)
	local bytecode_ok, bytecode = pcall(getscriptbytecode, script_obj)
	if not bytecode_ok then
		return nil
	end

	wait_rate_limit()

	local request_ok, response = pcall(request, {
		Url = "https://api.lua.expert/decompile",
		Method = "POST",
		Headers = { ["content-type"] = "application/json" },
		Body = http:JSONEncode({ script = (base64_encode or encode_base64)(bytecode) }),
	})

	if not request_ok then
		return "-- request() threw an error\n--[[\n" .. tostring(response) .. "\n--]]"
	end
	if not response or response.StatusCode ~= 200 then
		return "-- api request error\n--[[\n" .. (response and response.Body or "no response") .. "\n--]]"
	end

	local source = response.Body:gsub("^%-%- https://lua%.expert/%s*\n?", "")
	return "-- dumped by https://github.com/SirMadri/GetMapSrc\n-- decompiled by https://lua.expert/\n" .. source
end
