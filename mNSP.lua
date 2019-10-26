local event = require("event")
local ser = require("serialization")

-- mNSP protocol driver object
local mNSP = {
	-- Protocol name
	name = "mNSP",
	-- Protocol version
	version = 1,
	-- Protocol header version. Is used in packet header
	headerVersion = 5
}

mNSP.sockets = {}

-- Function onPacketReceive
-- It's required function for every protocol object
-- In case of session layer protocols, function's called from onPacketReceive of transport layer
-- ===
-- Arguments:
-- address - network address of the sender
-- port - port involved in message receivement
-- remotePort - port of remote machine
-- packet (table) - unserialized packet
function mNSP.onPacketReceive(address, port, remotePort, packet)
	sockets = mNSP.sockets[port]
	if sockets then
		for i = 1, #sockets do
			if address == sockets[i].address or not sockets[i].address then
				sockets[i]:appendInput(packet)
				for l = 1, #sockets[i].listeners do
					sockets[i].listeners[l](sockets[i], address, remotePort, packet)
				end
			end
		end
	end
end

-- Object-oriented part of the code

mNSP.NetworkStream = {}
-- Function newStream
-- Creates stream object
-- ===
-- Arguments:
-- streamType (string) - type of the stream
-- Available types: "s" (Send), "l" (Listen), "d" (Duplex)
-- address (mIP address) - address you want to connect to.
-- May be nil - in that case stream will be listening for incoming connections from all addresses. BUT it only works with "l" stream type.
-- If any other defined, an object will be nil
-- remotePort - port of a remote machine. Should be opened on it
-- localPort - port for handling replies from a remote machine.
-- For client machines it's recommended to not to define it - it will be replaced with randomly chosen one from user port range - 49152 to 65535
-- Returns:
-- Stream or nil
function mNSP.NetworkStream:newStream(streamType, address, remotePort, localPort)
    -- свойства
    local obj= {}

	if streamType ~= "l" and streamType ~= "d" and streamType ~= "w" then
		return nil
	end

	if not address and streamType ~= "l" then
		return nil
	end

	obj.output = ""
	obj.input = ""
	obj.listeners = {}
	obj.streamType = streamType
	obj.address = address
	obj.remotePort = remotePort
	obj.localPort = localPort or math.random(49152, 65535)

	require("OCNS").mUDP.openPort(obj.localPort)

	function obj:isReadable()
		return streamType == "d" or streamType == "l"
	end

	function obj:isWriteable()
		return streamType == "d" or streamType == "w"
	end

	if obj:isWriteable() then
		-- Function print
		-- Writes data to the stream and moves the carriage
		-- ===
		-- Arguments:
		-- data - data to write
		function obj:print(data)
			self:write(data .. "\n")
		end

		-- Function write
		-- writes data to the stream
		-- ===
		-- Arguments:
		-- data - data to write
		function obj:write(data)
			self.output = (self.output or "") .. data
		end

		-- Function flush
		-- Sends writen stream data to the remote host
		function obj:flush()
			-- Splitting stream into rows
			separator = "\n"
			for str in string.gmatch(obj.output, "([^" .. separator .. "]+)") do
				require("OCNS").mUDP.sendPacket(obj.address, obj.localPort, obj.remotePort, mNSP.headerVersion, str)
			end

			obj.output = ""
		end
	end

	if obj:isReadable() then
		-- Function isAvailable
		-- Checks whether there are any inoformation in the input stream
		-- ===
		-- Returns:
		-- boolean - is stream available for reading or not
		function obj:isAvailable()
			return #obj.input > 0
		end

		-- Function read
		-- Gets information from the stream
		-- ===
		-- Returns:
		-- string - read information
		function obj:read()
			-- Splitting stream into rows
			separator = "\n"
			str = string.gmatch(obj.input, "([^" .. separator .. "]+)")()
			if string.byte(obj.input, #obj.input) == 10 then
				obj.input = obj.input:sub(1, -2)
			end
			obj.input = obj.input:sub(#str + 2, -1)
			return str
		end

		-- The function is not a part of API and intended for internal use, so no documentation is provided
		function obj:appendInput(data)
			self.input = self.input .. data .. "\n"
		end

		-- Function awaitForAvailable
		-- Suspends a PC until stream will receive data
		function obj:awaitForAvailable()
			while not self:isAvailable() do
				require("computer").pullSignal(0.1)
			end
		end

		-- Function attachListener
		-- Adds a function that is called when data is arrived to the stream
		-- Params given to the function - stream, address, remotePort, data
		-- ===
		-- Arguments:
		-- listener (function) - function to attach
		function obj:attachListener(listener)
			if type(listener) == "function" then
				table.insert(self.listeners, listener)
			end
		end

		-- Function deleteListeners
		-- Removes all listeners from stream
		function obj:deleteListeners()
			self.listeners = {}
		end

		if not mNSP.sockets[obj.localPort] then mNSP.sockets[obj.localPort] = {} end

		table.insert(mNSP.sockets[obj.localPort], obj)
	end

	-- Function close
	-- Closes a stream and all related ports if needed
	-- ===
	-- Arguments:
	-- ID (number) - function to detach
	function obj:close()
		if self:isReadable() then
			-- Before closing the port, we should check if there are other streams using it
			if #mNSP.sockets[self.localPort] == 1 then
				require("OCNS").mUDP.closePort(self.localPort)
			end

			sockets = mNSP.sockets[self.localPort]
			for i = 1, #sockets do
				if sockets[i] == self then
					table.remove(mNSP.sockets[self.localPort], i)
				end
			end
		end
	end

    setmetatable(obj, self)
    self.__index = self; return obj
end

return mNSP
