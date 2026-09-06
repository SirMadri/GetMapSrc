-- remote module loader
--
-- every fetch is retried and guarded: a single failed HttpGet used to leave the
-- pending counter above zero forever, hanging the dumper with no error at all.
-- the pending count is derived from the module table so adding a module here
-- cannot desync it.

local base_url = "https://raw.githubusercontent.com/SirMadri/GetMapSrc/refs/heads/main/src"

local MODULES = {
	unc                      = "/UNC.luau",
	blocked_modules          = "/blocked_modules.luau",
	script_src               = "/script_src.luau",
	read_game                = "/read_game.luau",
	read_nil_instances       = "/read_nil_instances.luau",
	read_collection_service  = "/read_collection_service.luau",
	remote_src               = "/remote_src.luau",
	value_src                = "/value_src.luau",
	instance_meta            = "/instance_meta.luau",
	output                   = "/output.luau",
}

local MAX_ATTEMPTS = 3
local LOAD_TIMEOUT = 45

local repo = {}
local failed = {}
local pending = 0

for _ in next, MODULES do pending += 1 end

for module_name, file_path in next, MODULES do
	task.spawn(function()
		local url = base_url .. file_path
		local last_error = "unknown error"

		for attempt = 1, MAX_ATTEMPTS do
			local ok, result = pcall(function()
				local source = game:HttpGet(url)
				local chunk, compile_error = loadstring(source)
				if not chunk then error(tostring(compile_error), 0) end
				return chunk()
			end)

			if ok and result ~= nil then
				repo[module_name] = result
				pending -= 1
				return
			end

			last_error = tostring(result or "module returned nil")
			if attempt < MAX_ATTEMPTS then task.wait(attempt * 0.5) end
		end

		failed[module_name] = last_error
		pending -= 1
	end)
end

-- a request that never returns must not hang the dumper indefinitely
local deadline = os.clock() + LOAD_TIMEOUT
repeat task.wait() until pending == 0 or os.clock() > deadline

if pending > 0 or next(failed) then
	local problems = {}
	for module_name, err in next, failed do
		problems[#problems + 1] = module_name .. " (" .. err .. ")"
	end
	if pending > 0 then
		problems[#problems + 1] = pending .. " module(s) still pending after " .. LOAD_TIMEOUT .. "s"
	end
	error("-- failed to load dumper modules: " .. table.concat(problems, ", "), 0)
end

return repo
