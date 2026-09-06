local genv = getgenv()
local last_request_time = 0
local request_lock = false
local http_service = game:GetService("HttpService")
local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- executor functions live in the lexical global scope on some executors and in
-- getgenv() on others; resolve both instead of assuming one
local function pick(lexical, name)
	if lexical ~= nil then return lexical end
	local ok, value = pcall(rawget, genv, name)
	if ok and value ~= nil then return value end
	return nil
end

local fn_clone_ref         = pick(cloneref, "cloneref")
local fn_decompile         = pick(decompile, "decompile")
local fn_getscriptbytecode = pick(getscriptbytecode, "getscriptbytecode")
local fn_request           = pick(request, "request")
local fn_base64_encode     = pick(base64_encode, "base64_encode")

local http = fn_clone_ref and fn_clone_ref(http_service) or http_service

local LUAEXPERT_URL = "https://api.lua.expert/decompile"
local MAX_ATTEMPTS = 3
local MAX_BACKOFF = 10

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

local module = {}

-- exposed so the loader can rebuild a header for a script that shares its
-- bytecode with an already decompiled one, instead of decompiling it again
function module.header(script_obj, decompiler_name)
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
	if not fn_decompile then
		return nil, "executor decompile() is not available"
	end

	local decompile_ok, source = pcall(fn_decompile, script_obj)
	if not decompile_ok then
		return nil, "executor decompile() threw an error: " .. tostring(source)
	end

	source = tostring(source or "")
	if source == "" then
		return nil, "executor decompile() returned empty source"
	end

	return source
end

local function retry_delay(response, attempt)
	local headers = response and response.Headers
	if type(headers) == "table" then
		local after = tonumber(headers["retry-after"] or headers["Retry-After"])
		if after then return math.min(after, MAX_BACKOFF) end
	end
	return math.min(attempt * 2, MAX_BACKOFF)
end

local function decompile_with_luaexpert(script_obj)
	if not fn_getscriptbytecode then
		return nil, "getscriptbytecode is not available"
	end
	if not fn_request then
		return nil, "request is not available"
	end

	local bytecode_ok, bytecode = pcall(fn_getscriptbytecode, script_obj)
	if not bytecode_ok then
		return nil, "getscriptbytecode threw an error: " .. tostring(bytecode)
	end
	if not bytecode or bytecode == "" then
		return nil, "getscriptbytecode returned empty bytecode"
	end

	local encode = fn_base64_encode or encode_base64
	local body = http:JSONEncode({ script = encode(bytecode) })
	local last_error = "unknown error"

	-- rate limits and transient 5xx are retried with backoff; anything else is a
	-- real failure and returns immediately
	for attempt = 1, MAX_ATTEMPTS do
		wait_rate_limit()

		local request_ok, response = pcall(fn_request, {
			Url = LUAEXPERT_URL,
			Method = "POST",
			Headers = { ["content-type"] = "application/json" },
			Body = body,
		})

		local backoff = attempt

		if not request_ok then
			last_error = "request() threw an error: " .. tostring(response)
		elseif type(response) ~= "table" then
			last_error = "request() returned no response"
		else
			local status = tonumber(response.StatusCode) or 0
			if status == 200 then
				local response_body = response.Body
				if type(response_body) ~= "string" or response_body == "" then
					return nil, "lua.expert API returned empty body"
				end
				return (response_body:gsub("^%-%- https://lua%.expert/%s*\n?", "")), "https://lua.expert/"
			end

			last_error = "lua.expert API error " .. status .. ": " .. tostring(response.Body)
			if status ~= 429 and status < 500 then
				return nil, last_error
			end
			backoff = retry_delay(response, attempt)
		end

		if attempt < MAX_ATTEMPTS then task.wait(backoff) end
	end

	return nil, last_error .. " (after " .. MAX_ATTEMPTS .. " attempts)"
end

local DECOMPILERS = {
	executor = decompile_with_executor,
	luaexpert = decompile_with_luaexpert,
}

-- returns full_source, decompiler_name, body
-- body is the source without the header, so callers can re-header it for a
-- script with identical bytecode
function module.decompile(script_obj, options)
	local errors = {}
	for _, method in ipairs(get_method_order(get_decompiler_method(options))) do
		local decompiler = DECOMPILERS[method]
		if decompiler then
			local source, decompiler_name = decompiler(script_obj)
			if source then
				return module.header(script_obj, decompiler_name) .. source, decompiler_name, source
			end
			errors[#errors + 1] = method .. ": " .. tostring(decompiler_name)
		else
			errors[#errors + 1] = method .. ": unknown decompiler"
		end
	end

	return nil, table.concat(errors, "\n")
end

-- callable table keeps the existing repo.script_src(obj, options) call working
return setmetatable(module, {
	__call = function(_, script_obj, options)
		return module.decompile(script_obj, options)
	end,
})
