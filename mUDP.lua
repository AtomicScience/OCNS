local event = require("event")
local ser = require("serialization")

-- mUDP protocol driver object
local mUDP = {
	-- Protocol name
	name = "mUDP",
	-- Protocol version
	version = 1,
	-- Protocol header version. Is used in packet header
	headerVersion = 4
}

mUDP.handlingPorts = {}
mUDP.listeners = {}

-- Function formPacket
-- Packs arguments into a table and appends a version field
function mUDP.formPacket(sourcePort, destinationPort, version, data)
	return 4, {sourcePort, destinationPort, version, data}
end

-- Function sendPacket  
-- Sends a packet
-- ===
-- Arguments:
-- address (mIP address) - address of the sender
-- sourcePort (number) - port you send your packet FROM
-- destinationPort (number) - port you send your packet TO
-- version, data - got directly from high-level protocol
function mUDP.sendPacket(address, sourcePort, destinationPort, version, data)
	require("OCNS").mIP.sendPacket(address, mUDP.formPacket(sourcePort, destinationPort, version, ser.serialize(data)))
end

-- Function openPort  
-- Starts handling a specified port
-- ===
-- Arguments:
-- port - port to handle
-- Returns:
-- boolean - was port opened or not (it's already being handling)
function mUDP.openPort(port)
	-- If port is absent in the table, we should add it, else - 'return false'
	if not mUDP.handlingPorts[port] then
		mUDP.handlingPorts[port] = true
		return true
	else
		return false
	end
end

-- Function closePort  
-- Stops handling a specified port
-- ===
-- Arguments:
-- port - port to close
-- Returns:
-- boolean - was port opened or not (it's already being handling)
function mUDP.closePort(port)
	-- If port is present in the table, we remove add it, else - 'return false'
	if mUDP.handlingPorts[port] then
		mUDP.handlingPorts[port] = nil
		return true
	else
		return false
	end
end

-- Function onPacketReceive  
-- It's required function for every protocol object
-- In case of transport layer protocols, function's called from onPacketReceive of network layer
-- ===
-- Arguments:
-- address - network address of the sender
-- lowerProtocol - an object of the protocol that have received the packet
-- packet (table) - unserialized packet
function mUDP.onPacketReceive(address, lowerProtocol, packet)
	-- We should proceed only if 'destination port' is open
	if mUDP.handlingPorts[packet[2]] then
		require("OCNS").decapsulateToSession(address, packet[1], packet[2], packet[3], packet[4])
		
		-- Calling listener functions
		listeners = mUDP.listeners[packet[2]]
		if listeners then
			for i = 1, #listeners do
				listeners[i](address, packet[4], packet[2], packet[3])
			end
		end 
		
		-- Invoking an "mudp_message" event
		event.push("mudp_message", address, packet[4], packet[2], packet[3])
	end
	
	-- 8 port is ping port
	if packet[2] == 8 then
		mUDP.sendPacket(address, 8, packet[1], packet[3], packet[4])
	end
end

-- Function attachListener
-- Adds a function that will be triggered when mUDP message arrives
-- Note, that you still have to open ports manualy
-- ===
-- Arguments:
-- port (number) - port you want to listen
-- listenter (function) - listener itself. Is called with arguments "address", "payload", "port", "remotePort".
function mUDP.attachListener(port, listener)
	if not mUDP.listeners[port] then mUDP.listeners[port] = {} end
	table.insert(mUDP.listeners[port], listener)
end

-- Function detachListeners
-- Removes listeners from the system
-- ===
-- Arguments:
-- port (number) - port you want to remove listeners from. If nil, ALL the listeners will be deleted
function mUDP.detachListeners(port)
	if port then
		mUDP.listeners[port] = {}
	else
		mUDP.listeners = {}
	end
end

return mUDP