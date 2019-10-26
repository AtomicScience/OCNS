local mIP = require("OCNS.mIP")
local modem = require("component").modem
local computer = require("computer")
local ser = require("serialization")
local event = require("event")

-- mARP v1
-- This protocol is responsible for seeking physical addresses of known mIP adresses holders
--
-- Packets structure:
-- Request:
-- +----+----------+---------------+
-- |Type|Source mIP|Destination mIP|
-- +----+----------+---------------+
-- Type is 0
-- Reply
-- +----+----------+-----------------------+
-- |Type|Source mIP|Source physical address|
-- +----+----------+-----------------------+
-- Type is 1

local mARP = {
	-- Protocol name
	name = "mARP",
	-- Protocol version
	version = 1,
	-- Protocol header version. Is used in packet header
	headerVersion = 2
}

-- Function formRequestPacket
-- Makes a mARP request packet, ready to be transferred via modem.send
-- ===
-- Arguments:
-- destinationAddress (mARP address) - address you want too seek
-- sourceAddress (mARP address) - address of the sender. If not provided, your address will be attached to the package
-- Returns:
-- Packet (table), ready to be transferred via modem.send
function mARP.formRequestPacket(destinationAddress)
	-- Make a table out of our arguments and return it
	return {0, mIP.localSettings.address, destinationAddress}
end

-- Function formRespondPacket
-- Makes a mARP respond packet, ready to be transferred via modem.send
-- ===
-- Arguments:
-- destinationAddress (mARP address) - address you want too reply
-- sourceAddress (string) - physical address of the responder. If not provided, your address will be attached to the package
-- Returns:
-- Packet (table), ready to be transferred via modem.send
function mARP.formRespondPacket()
	-- Make a table out of our arguments and return it
	return {1, mIP.localSettings.address, modem.address}

end

-- Function sendRequest
-- Sends a request to seek provided addresss and waits for the result. Method suspends the PC until respond will be received or request will timeout
-- ===
-- Arguments:
-- address (mIP address) - address you want to seek
-- Returns:
-- success (boolean) - was request successful or not
function mARP.sendRequest(address)
	-- Broadcasting an mARP request
	modem.broadcast(13, 2, ser.serialize(mARP.formRequestPacket(address)))
	-- Avaiting for respond paying attention to request timeout
	-- Warning: "marp_respond" event is intend for internal use only, so no description and documentation is provided
	_, source_mIP, source_physical = event.pull(mARP.localSettings.requestTimeout, "marp_respond")
	if not source_mIP then
		return false
	end
	mARP.addTableEntry(source_mIP, source_physical)
	return true
end

-- Function sendRespond
-- Sends a respond
-- ===
-- Arguments:
-- mIP, physical (mIP address, string) - addresses of responder
function mARP.sendRespond(mIP, physical)
	-- Sending an mARP respond
	-- Memo - '13' is default port of all the protocols, '2' is 'Version' field, '1' is 'Type' field
	modem.send(physical, 13, 2, ser.serialize(mARP.formRespondPacket()))

	mARP.addTableEntry(mIP, physical)
	return
end

-- Function onPacketReceive
	return
end

-- Function onPacketReceive
-- It's required function for every protocol object
-- In case of network layer protocols, function's called from network driver (98_network.lua in /boot)
-- ===
-- Arguments:
-- address - physical address of the sender
-- packet - unserialized packet
function mARP.onPacketReceive(address, packet)
	-- Packet contents:
	-- packet[1] - type
	-- packet[2] - source mIP address
	-- packet[3] - destination mIP address

	-- Firstly we have to check packet's type (0 is request, 1 is
	if packet[1] == 0 then
		-- It's ARP request! Now we should compare our address with address in request
		if packet[3] == mIP.localSettings.address then
			-- Gotcha! Sending a mARP respond
			mARP.sendRespond(packet[2], address)
		end
	elseif packet[1] == 1 then
		-- It's mARP respond!
		-- Probably, I've should have had to add here some measures to avoid mARP-spoofing, but, to be honest, I don't care :)
		-- Warning: "marp_respond" event is intended for internal use only, so no description and documentation is provided
		event.push("marp_respond", packet[2], address)
	else
		error("Wrong ARP packet!")
	end
end

-- Function addTableEntry
-- Adds a mARP table entry or just refreshes the timestamp, if it's already represented in the table
-- ===
-- Arguments:
-- mIP, physical - addresses you want to link
-- Order is unnecessary
function mARP.addTableEntry(mIP, physical)
	if not mARP.table[mIP] then
		mARP.table[mIP] = physical
	end
	-- Timestamps via computer.uptime()
	mARP.table.timestamps[mIP] = computer.uptime()
end

-- Function addTableEntry
-- Gets a mARP entry from the table. If it's expired or not represented, nil will be returned
-- ===
-- Arguments:
-- address (number) - address you want to get
-- sendRequest (boolean) - should method send request if the record is expired or absent
function mARP.getTableEntry(address, sendRequest)
	foundAddress = mARP.table[address]
	timestamp = mARP.table.timestamps[address]

	-- If there is corresponding entry ('if timestamp' checks whether there if entry is represented) and it's expired, we should delete it
	if timestamp and (computer.uptime() - timestamp > mARP.localSettings.recordTimeout) then
		mARP.table[address] = nil
		mARP.table.timestamps[address] = nil

		-- Our record is expired, so we have to send the request again, but only if method caller allowed us to do it
		if sendRequest then mARP.sendRequest(address) end

		return mARP.getTableEntry(address)
	end

		-- Our record is expired, so we have to send the request again, but only if method caller allowed us to do it
		if sendRequest then mARP.sendRequest(address) end

		return mARP.getTableEntry(address)
	end
	-- If we didn't found address, let's seek it and return the result
	if not foundAddress and sendRequest then
		mARP.sendRequest(address)
		mARP.getTableEntry(address)
	end
	return foundAddress
end

-- Function clearTable
-- Removes all the entries from table (or initializes it)
-- ===
-- Arguments:
-- address - address you want to get
-- Address type is unnecessary
function mARP.clearTable()
	-- The table
	mARP.table = {}
	-- Timestamps table
	mARP.table.timestamps = {}
end

-- We initiazile our table with this method
mARP.clearTable()

mARP.localSettings = {
	-- Timeout of mARP record in seconds
	recordTimeout = require("OCNS.utils").confman.config.mARP.recordTimeout,
	-- Timeout of mARP request in seconds
	requestTimeout = require("OCNS.utils").confman.config.mARP.requestTimeout
}
return mARP
