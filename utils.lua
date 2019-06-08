-- Utils for OCNS
-- Contains:
-- 1) Configuration manager 

local utils = {}
-- Configuration manager
utils.confman = {}

local timestamp = 0

function utils.writeDelayToFile(file, method)
	stream = io.open(file, "a")
	stream:write(method .. ": " .. (require("computer").uptime() - timestamp) .. "\n")
	timestamp = require("computer").uptime()
	stream:flush()
	io.close(stream)
end

function utils.confman.loadConfig(file)
	local env = {}
	env.mIP = {}
	env.mARP = {}
    local config = loadfile(file, nil, env)
    if config then
      pcall(config)
    end
	
	-- Just to check if config is represented in fil
	if not (env.mIP.address and env.mARP.recordTimeout and env.mARP.requestTimeout) then
      utils.confman.saveDefaultConfig(file)
	  utils.confman.loadConfig(file)
    end
	
	return env
end


function utils.confman.saveConfig(file)
	local stack = require("OCNS")
	stream = io.open(file, "w")
	io.output(stream)
	print("mIP.address = \"" .. stack.mIP.prettifyAddress(stack.mIP.localSettings.address) .. "\"")
	print("mARP.recordTimeout = " .. stack.mARP.localSettings.recordTimeout)
	print("mARP.requestTimeout = " .. stack.mARP.localSettings.requestTimeout)
	stream:flush()
	io.close(stream)
end

function utils.confman.saveDefaultConfig(file)
	stream = io.open(file, "w")
	io.output(stream)
	print("mIP.address = \"192.168.1\"")
	print("mARP.recordTimeout = 300")
	print("mARP.requestTimeout = 2")
	stream:flush()
	io.close(stream)
end

utils.confman.config = utils.confman.loadConfig("/etc/network.cfg")

return utils