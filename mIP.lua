local bit = require("bit32")
local modem = require("component").modem
local ser = require("serialization")
local event = require("event")

-- mIP v1
-- Basic implementation of network layer protocol, supports PC labeling with 3-octet 24-bit addresses
-- Currently have nothing but labeling PCs and sending packets in one Ethernet with resolving names via mARP
--
-- Packets structure:
-- +----+----------+---------------+-------+
-- |Type|Source mIP|Destination mIP|Payload|
-- +----+----------+---------------+-------+
-- Version is 1

-- mIP protocol driver object
local mIP = {
	-- Protocol name
	name = "mIP",
	-- Protocol version
	version = 1,
	-- Protocol header version. Is used in packet header
	headerVersion = 1
}

mIP.listeners = {}

-- Function formPacket
-- Makes a mIP packet, ready to be transferred via modem.send
-- ===
-- Arguments:
-- destinationAddress (mIP address) - address of the destination
-- payload (table) - actual load of the package
-- sourceAddress (mIP address) - address of the sender. If not provided, your address will be attached to the package
-- Returns:
-- Packet (table), ready to be transferred via modem.send
function mIP.formPacket(destinationAddress, version, payload)
	-- Make a table out of our arguments and return it
	return {mIP.localSettings.address, destinationAddress, version, ser.serialize(payload)}
end

-- Function prettifyAddress
-- Represents your baked address as x.x.x human-form address
-- Despite the function name, it's obviously useable with masks and other 3-octet stuffs
-- ==
-- Arguments:
-- bakedAddress (number) - address to be prettified
-- Returns
-- Raw address (number) - address, that could be easily read by human
function mIP.prettifyAddress(bakedAddress)
	address = "" .. bit.rshift(bakedAddress, 16)
	address = address .. "." .. bit.rshift(bit.lshift(bakedAddress, 16), 24)
	address = address .. "." .. bit.rshift(bit.lshift(bakedAddress, 24), 24)

	return address
end

-- Function bakeAddress
-- Represents your x.x.x address as a number, processable with code.
-- Despite the function name, it's obviously useable with masks and other 3-octet stuffs
-- ==
-- Arguments:
-- rawAddress (string) - address to be baked
-- Returns
-- Baked address (number) - address, that could be used in other driver metods
-- ==
-- Throws an error:
-- When address is invalid
function mIP.bakeAddress(rawAddress)
	if not (rawAddress == nil or mIP.isValidAddress(rawAddress)) then
		error("Invalid address!")
	end

	-- Enumirating our octets, we are doing few things:
	-- 1) Checking if octet is representing a valid 8-bit number (it should not be bigger than 255 in decimal form)
	-- 2) Caclulating a number-form address by translating octets into numbers and summing them with left-shift
	-- ==================
	-- Look how it works:
	-- Example address: 255.127.255
	-- 1 octet: 255 = 1111111 in binary
	-- Shifting 11111111 by 16 positions left we get 11111111.0000000.0000000 (points are put just for clarity)
	-- 2 octet: 127 = 0111111 in binary
	-- Shifting 01111111 by 8 positions left we get 0000000.0111111.0000000 (points are put just for clarity)
	-- 2 octet: 255 = 1111111 in binary
	-- Without shifting, we get 0000000.0000000.11111111 (points are put just for clarity)
	-- Summing these three values we get our address in binary form - 11111111.01111111.11111111 or 16744447 in decimal

	-- This value represents our shift degree
	degree = 16
	-- Our value to be returned
	address = 0
	for S in string.gmatch(rawAddress, "%d+") do
		octet = tonumber(S)
		if octet > 255 then
			error("Invalid address!")
		end

		address = address + bit.lshift(octet, degree)
		degree = degree - 8
	end

	return address
end

-- Function isValidAddress
-- Checks whether provied "pretty" address is valid or not
-- ===
-- Arguments:
-- address (string) - pretty address you want to check
-- Returns:
-- (boolean) - address validness
function mIP.isValidAddress(address)
	-- Checking whether our address is valid using regular expressions magic.
	return string.find(address, "^(%d+)%.(%d+)%.(%d+)$") == 1
end

-- Function changeAddress
-- Changes client address
-- ===
-- Arguments:
-- address (string OR number) - address you want to set
-- ==
-- Throws an error:
-- When address is invalid
function mIP.changeAddress(address)
	if type(address) == "string" then
		mIP.localSettings.address = mIP.bakeAddress(address)
	else
		mIP.localSettings.address = address
	end
	-- Saving configuration
	require("OCNS").utils.confman.saveConfig("/etc/network.cfg")
end

-- Function sendPacket
-- Sends a mIP packet
-- ===
-- Arguments:
-- destinationAddress (mIP address) - address to deliver payload
-- payload (table) - data to send
-- version (number) - header version of a higher level protocol
-- Returns:
-- string - error message or nil if success
function mIP.sendPacket(destinationAddress, version, payload)
	-- We get a destination address with mARP. 'true' argument lets the protocol to send a request if address is not represented in the table
	destinationPhysical = require("OCNS").mARP.getTableEntry(destinationAddress, true)

	-- If destinationPhysical == nil (mARP request failed) we should send an error message
	if not destinationPhysical then
		return "Address is unreachable"
	end

	modem.send(destinationPhysical, 13, 1, ser.serialize(mIP.formPacket(destinationAddress, version, ser.serialize(payload))))
	return nil
end

-- Function onPacketReceive
-- It's required function for every protocol object
-- In case of network layer protocols, function's called from network driver (98_network.lua in /boot)
-- ===
-- Arguments:
-- address - physical address of the sender
-- packet (table) - unserialized packet
function mIP.onPacketReceive(address, packet)
	-- Packet contents:
	-- packet[1] - source mIP (local address)
	-- packet[2] - destination mIP (remote address)
	-- packet[3] - transport layer protocol header version
	-- packet[4] - serialized payload

	-- Just a normal one event to help normal ones to use a network without that imposed by stupid developer nerdy crap like "protocols" and other shit
	-- Is only called if normal ones used 0 as header version
	if packet[3] == 0 then
		event.push("mip_message", packet[1], packet[2], ser.unserialize(packet[4]))

		-- Calling all of registerd listeners
		for i = 1, #mIP.listeners do
			mIP.listeners[i](packet[1], packet[2], ser.unserialize(packet[4]))
		end
	end

	-- Adding or refreshing a mARP table record
	mARP.addTableEntry(packet[2], address)

	--require("OCNS").utils.writeDelayToFile("/home/debug.log", "mIP.onPacketReceive")
	require("OCNS").decapsulateToTransport(packet[1], mIP, packet[3], ser.unserialize(packet[4]))
end

-- Function attachListener
-- Adds a function that will be triggered when mIP message arrives
-- ===
-- Arguments:
-- listenter (function) - listener itself. Is called with arguments "localAddress", "remoteAddress", "payload",.
function mIP.attachListener(listener)
	if not mIP.listeners then mIP.listeners = {} end
	table.insert(mIP.listeners, listener)
end

-- Function detachListeners
-- Removes listeners from the system
function mIP.detachListeners()
	mIP.listeners = {}
end

-- This table contains your client settings, such as address, mask, default gateway and others
mIP.localSettings = {
	-- Your mIP address. bakeAddress function is called to turn a human-form address view into a machine-form - number
	address = mIP.bakeAddress(require("OCNS.utils").confman.config.mIP.address)
}

return mIP
