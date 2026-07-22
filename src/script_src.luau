local genv = getgenv()
local last_request_time = 0
local request_lock = false
local http_service = game:GetService("HttpService")
local http = cloneref and cloneref(http_service) or http_service
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
	if elapsed < 0.04 then task.wait(0.04 - elapsed) end
	last_request_time = os.clock()
	request_lock = false
end

local function normalize_decompiler(value)
	local method = tostring(value or "auto"):lower():gsub("%s+", "")
	if method == "" or method == "auto" then
		return "auto"
	end
	if method == "executor" or method == "native" or method == "decompile" then
		return "executor"
	end
	if method == "luaexpert" or method == "lua.expert" or method == "lua_expert" or method == "api" then
		return "luaexpert"
	end
	return method
end

local function get_decompiler_method(options)
	if type(options) == "string" then
		return normalize_decompiler(options)
	end
	if type(options) == "table" then
		return normalize_decompiler(options.decompiler or options.decompile_method)
	end
	return "auto"
end

local function get_method_order(method)
	if method == "executor" then
		return { "executor" }
	end
	if method == "luaexpert" then
		return { "luaexpert" }
	end
	return { "executor", "luaexpert" }
end

local function header_for(script_obj, decompiler_name)
	local lines = {
		"-- dumped by https://github.com/SirMadri/GetMapSrc",
	}
	if decompiler_name then
		lines[#lines + 1] = "-- decompiled by " .. decompiler_name
	else
		lines[#lines + 1] = ""
	end
	lines[#lines + 1] = "-- Name: " .. script_obj.Name
	lines[#lines + 1] = "-- ClassName: " .. script_obj.ClassName
	lines[#lines + 1] = "-- Path: " .. script_obj:GetFullName()
	lines[#lines + 1] = ""
	return table.concat(lines, "\n")
end

local function decompile_with_executor(script_obj)
	if not genv.decompile then
		return nil, "executor decompile() is not available"
	end

	local decompile_ok, source = pcall(genv.decompile, script_obj)
	if not decompile_ok then
		return nil, "executor decompile() threw an error: " .. tostring(source)
	end

	source = tostring(source or "")
	if source == "" then
		return nil, "executor decompile() returned empty source"
	end

	return source
end

local function decompile_with_luaexpert(script_obj)
	if not genv.getscriptbytecode then
		return nil, "getscriptbytecode is not available"
	end
	if not genv.request then
		return nil, "request is not available"
	end

	local bytecode_ok, bytecode = pcall(genv.getscriptbytecode, script_obj)
	if not bytecode_ok then
		return nil, "getscriptbytecode threw an error: " .. tostring(bytecode)
	end
	if not bytecode or bytecode == "" then
		return nil, "getscriptbytecode returned empty bytecode"
	end

	wait_rate_limit()
	local encode = genv.base64_encode or encode_base64

	local request_ok, response = pcall(genv.request, {
		Url = "https://api.lua.expert/decompile",
		Method = "POST",
		Headers = { ["content-type"] = "application/json" },
		Body = http:JSONEncode({ script = encode(bytecode) }),
	})

	if not request_ok then
		return nil, "request() threw an error: " .. tostring(response)
	end
	if not response or response.StatusCode ~= 200 then
		return nil, "lua.expert API request error: " .. (response and response.Body or "no response")
	end

	local body = response.Body
	if type(body) ~= "string" or body == "" then
		return nil, "lua.expert API returned empty body"
	end

	local source = body:gsub("^%-%- https://lua%.expert/%s*\n?", "")
	return source, "https://lua.expert/"
end

local DECOMPILERS = {
	executor = decompile_with_executor,
	luaexpert = decompile_with_luaexpert,
}

return function(script_obj, options)
	local errors = {}
	for _, method in ipairs(get_method_order(get_decompiler_method(options))) do
		local decompiler = DECOMPILERS[method]
		if decompiler then
			local source, decompiler_name = decompiler(script_obj)
			if source then
				return header_for(script_obj, decompiler_name) .. source, decompiler_name
			end
			errors[#errors + 1] = method .. ": " .. tostring(decompiler_name)
		else
			errors[#errors + 1] = method .. ": unknown decompiler"
		end
	end

	return nil, table.concat(errors, "\n")
end
