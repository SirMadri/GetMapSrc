local genv = getgenv()
local caps = {}

-- request
if genv.request then
	caps.request = "request"
else
	caps.request = nil
end

-- cloneref
if genv.cloneref then
	caps.cloneref = true
else
	genv.cloneref = function(ref) return ref end
	caps.cloneref = false
end

-- bytecode, nilinstance & b64
caps.getscriptbytecode  = genv.getscriptbytecode ~= nil
caps.base64_encode      = genv.base64_encode ~= nil
caps.getnilinstances    = genv.getnilinstances ~= nil

-- filesystem
caps.isfolder   = genv.isfolder ~= nil
caps.makefolder = genv.makefolder ~= nil
caps.writefile  = genv.writefile ~= nil
caps.readfile   = genv.readfile ~= nil

-- getgenv / setgenv
caps.getgenv = genv.getgenv ~= nil
caps.setgenv = genv.setgenv ~= nil

-- loadstring
caps.loadstring = genv.loadstring ~= nil or loadstring ~= nil

-- support
caps.can_decompile  = caps.getscriptbytecode and caps.request ~= nil
caps.can_write      = caps.isfolder and caps.makefolder and caps.writefile

return caps