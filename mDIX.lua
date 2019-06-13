local ser = require("serialization")

local mDIX = {
	-- Protocol name
	name = "mDIX",
	-- Protocol version
	version = 1,
	-- Protocol header version. Is used in packet header
	headerVersion = 6
}

-- Function formPacket
-- Forms a packet ready to be transmitted via interface after serialization
function mDIX.formPacket(dAddress, dPort, sAddress, sPort, version, payload)
	return {localPort, dAddress, dPort, sAddress, sPort, version, ser.serialize(payload)}
end

-- Function sendPacket
-- Sends a mDIX packet
-- ===
-- Arguments:
-- interface (object) - interface driver you want to use
-- localPort (number) - port you want to mark as source. Set to nil if you
-- want to use auto-generated one
-- version (number) - header version of a higher level protocol
-- Returns:
-- string - error message or nil if success
function mDIX.sendPacket(interface, sourcePort, destinationAddress, destinationPort, version, payload)
	local packet = mDIX.formPacket(destinationAddress, destinationPort, interface.physicalAddress, version, payload)
	interface:send(destinationPort, mDIX.headerVersion, packet)
end

-- Function onPacketReceive
-- It's required function for every protocol object
-- In case of data link layer protocols, it's called from network driver
-- ===
-- Arguments:
-- interface - interface that received the message
-- packet (table) - unserialized packet
function mDIX.onPacketReceive(interface, packet)

end

return mDIX
