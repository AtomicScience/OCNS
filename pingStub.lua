local event = require("event")

-- pingStub protocol driver object
local pingStub = {
	-- Protocol name
	name = "pingStub",
	-- Protocol version
	version = 1,
	-- Protocol header version. Is used in packet header
	headerVersion = 3
}

-- Function sendRequest
-- Sends an pingStub request. Method suspends the PC until respond will be received or request will timeout
-- ===
-- Arguments:
-- destinationAddress (mIP address) - address to request to
-- timeout (number) - request timeout (in seconds)
-- sendAndForget (boolean) - determines if PC should be suspended until the reply will be received or timeout will expire
-- Returns:
-- string - error message, or nil if success
function pingStub.sendRequest(destinationAddress, timeout, sendAndForget)
	errorMessage = require("OCNS").mIP.sendPacket(destinationAddress, 3, {0})
	timeout = timeout or 8
	if errorMessage then
		return errorMessage
	end
	
	
	if not sendAndForget then 
		eventName = event.pull(timeout, "pingstub_reply") 
	end
	
	if not (eventName or sendAndForget) then
		return "Request timeout"
	end
	
	return nil
end

-- Function sendReply
-- Sends an pingStub reply
-- ===
-- Arguments:
-- destinationAddress (mIP address) - address to reply to
-- Returns:
-- string - error message or nil if success
function pingStub.sendReply(destinationAddress)
	errorMessage = require("OCNS").mIP.sendPacket(destinationAddress, 3, {1})
	
	if errorMessage then
		return errorMessage
	end
	
	--require("OCNS").utils.writeDelayToFile("/home/debug.log/", "pingStub.sendReply")
	return nil
end

-- Function onPacketReceive  
-- It's required function for every protocol object
-- In case of transport layer protocols, function's called from onPacketReceive of network layer
-- ===
-- Arguments:
-- address - network address of the sender
-- lowerProtocol - an object of the protocol that have received the packet
-- packet (table) - unserialized packet
function pingStub.onPacketReceive(address, lowerProtocol, packet)
	-- Packet contents
	-- packet[1] - packet type
	
	-- Checking the packet type
	if packet[1] == 0 then
		-- It's request! We have to reply!
		--require("OCNS").utils.writeDelayToFile("/home/debug.log", "pingStub.onPacketReceive")
		pingStub.sendReply(address)		
	elseif packet[1] == 1 then
		-- It's reply! Invoking the event
		--require("OCNS").utils.writeDelayToFile("/home/debug.log", "pingStub.onPacketReceive")
		event.push("pingstub_reply")
	else
		-- lowerProtocol.sendPackage(address, 228, {"И нахуя мне эта информация????"})
	end
end

return pingStub