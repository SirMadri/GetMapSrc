-- capability probe
--
-- executor functions are resolved from the lexical global scope first and from
-- getgenv() second: some executors expose one but not the other, and checking
-- only getgenv() made the loader refuse to run on a perfectly usable filesystem.
-- nothing is written back into getgenv() here.

local genv = getgenv()

local function pick(lexical, name)
	if lexical ~= nil then return lexical end
	local ok, value = pcall(rawget, genv, name)
	if ok and value ~= nil then return value end
	return nil
end

local fn = {
	request           = pick(request, "request"),
	cloneref          = pick(cloneref, "cloneref"),
	decompile         = pick(decompile, "decompile"),
	getscriptbytecode = pick(getscriptbytecode, "getscriptbytecode"),
	getscripthash     = pick(getscripthash, "getscripthash"),
	getnilinstances   = pick(getnilinstances, "getnilinstances"),
	getmodules        = pick(getmodules, "getmodules"),
	base64_encode     = pick(base64_encode, "base64_encode"),
	isfolder          = pick(isfolder, "isfolder"),
	makefolder        = pick(makefolder, "makefolder"),
	writefile         = pick(writefile, "writefile"),
	readfile          = pick(readfile, "readfile"),
	appendfile        = pick(appendfile, "appendfile"),
	isfile            = pick(isfile, "isfile"),
	delfile           = pick(delfile, "delfile"),
	loadstring        = pick(loadstring, "loadstring"),
	setgenv           = pick(setgenv, "setgenv"),
}

local caps = { fn = fn }

for name, value in next, fn do
	caps[name] = value ~= nil
end

-- callers get a usable reference instead of a global side effect
caps.clone_ref = fn.cloneref or function(ref) return ref end
caps.getgenv = true

-- support
caps.can_luaexpert = caps.getscriptbytecode and caps.request
caps.can_decompile = caps.decompile or caps.can_luaexpert
caps.can_write     = caps.isfolder and caps.makefolder and caps.writefile
caps.can_resume    = caps.isfile and caps.readfile and caps.writefile
caps.can_dedupe    = caps.getscripthash

return caps
