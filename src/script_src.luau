-- Script made by https://lua.expert

assert(getscriptbytecode, "exploit does not support getscriptbytecode.")

local last = 0
local lock = false
local http = cloneref and cloneref(game:GetService("HttpService")) or game:GetService("HttpService")
local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function encode(data)
	local t, pad = {}, #data % 3
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i), data:byte(i+1) or 0, data:byte(i+2) or 0
		local n = a*65536 + b*256 + c
		t[#t+1] = b64:sub(math.floor(n/262144)%64+1, math.floor(n/262144)%64+1)
		t[#t+1] = b64:sub(math.floor(n/4096)%64+1, math.floor(n/4096)%64+1)
		t[#t+1] = b64:sub(math.floor(n/64)%64+1, math.floor(n/64)%64+1)
		t[#t+1] = b64:sub(n%64+1, n%64+1)
	end
	if pad == 1 then t[#t-1], t[#t] = "=", "="
	elseif pad == 2 then t[#t] = "=" end
	return table.concat(t)
end

return function(scr)
	local ok, bc = pcall(getscriptbytecode, scr)
	if not ok then return "-- failed to read script bytecode\n--[[\n"..bc.."\n--]]" end

	-- mutex: só uma coroutine passa por aqui por vez, garantindo o rate limit global
	while lock do task.wait() end
	lock = true
	local elapsed = os.clock() - last
	if elapsed < 0.12 then task.wait(0.12 - elapsed) end
	last = os.clock()
	lock = false

	-- request acontece fora do lock — várias podem estar in-flight ao mesmo tempo
	local res = request({
		Url = "https://api.lua.expert/decompile",
		Method = "POST",
		Headers = { ["content-type"] = "application/json" },
		Body = http:JSONEncode({ script = (base64_encode or encode)(bc) })
	})

	if not res or res.StatusCode ~= 200 then
		return "-- api request error\n--[[\n"..(res and res.Body or "no response").."\n--]]"
	end
	return res.Body
end
