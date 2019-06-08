local ser = require("serialization")

-- OCNS - OpenComputers Network Stack
-- OCNS is the protocol stack, which tries to closely implement protocols of real-life
-- TCP/IP stack. To avoid confusion, all protocols have 'm' in their names (e.g. IP -> mIP)
-- ==
-- Implemented protocols:
-- mIPv1 - basic implementation of IP protocol, supports PC naming with 3-octet 24-bit addresses 
-- Currently have nothing but labeling PCs and sending packets in one Ethernet
-- mARPv1 - ARP-like protocol for OCNS networks
-- pingStub - simple layer 4 protocol designed to test networks in a very simple way

local OCNS = {}

OCNS.utils = require("OCNS.utils")
OCNS.mIP = require("OCNS.mIP")
OCNS.mUDP = require("OCNS.mUDP")
OCNS.mARP = require("OCNS.mARP")
OCNS.pingStub = require("OCNS.pingStub")
OCNS.mNSP = require("OCNS.mNSP")

OCNS.networkProtocols = {OCNS.mIP, OCNS.mARP}
OCNS.transportProtocols = {OCNS.pingStub, OCNS.mUDP}
OCNS.sessionProtocols = {OCNS.mNSP}

-- Function decapsulateToNetworkLayer (yes, I'm the fan of long method names)
-- Is called when "modem_message" is triggered. Detects a network protocol and calls "onPacketReceive" method of it
-- ===
-- Arguments:
-- Many-many-many arguments that are passed directly from "modem_message" event
function OCNS.decapsulateToNetworkLayer(_, localInterface, senderInterface, port, _, version, payload)
	--OCNS.utils.writeDelayToFile("/home/debug.log", "-----------------")
	
	for i = 1, #OCNS.networkProtocols do
		protocol = OCNS.networkProtocols[i]
		if version == protocol.headerVersion then
			-- OCNS.utils.writeDelayToFile("/home/debug.log", "decapsulateToNetworkLayer")
			protocol.onPacketReceive(senderInterface, ser.unserialize(payload))
		end
	end
end

-- Function decapsulateToTransportLayer
-- Is called from network layer protocols to pass package to higher level - transport
-- ===
-- Arguments:
-- senderAddress - address (mIP or other network layer address) of the senderAddress
-- lowerProtocol - protocol driver object which received the frame
-- version, payload - got directly from network layer package payload
function OCNS.decapsulateToTransport(senderAddress, lowerProtocol, version, payload)
	for i = 1, #OCNS.transportProtocols do
		protocol = OCNS.transportProtocols[i]
		if version == protocol.headerVersion then
			--OCNS.utils.writeDelayToFile("/home/debug.log", "decapsulateToTransportLayer")
			protocol.onPacketReceive(senderAddress, lowerProtocol, ser.unserialize(payload))
		end
	end
end

-- Function decapsulateToSession
-- Is called from transport layer protocols
-- ===
-- Arguments:
-- senderAddress - address (mIP or other network layer address) of the senderAddress
-- port - port that received the message
-- protocol - protocol driver object which received the frame
-- version, payload - got directly from network layer package payload
function OCNS.decapsulateToSession(senderAddress, remotePort, port, version, payload)
	for i = 1, #OCNS.sessionProtocols do
		protocol = OCNS.sessionProtocols[i]
		if version == protocol.headerVersion then
			--OCNS.utils.writeDelayToFile("/home/debug.log", "decapsulateToTransportLayer")
			protocol.onPacketReceive(senderAddress, port, remotePort, ser.unserialize(payload))
		end
	end
end

return OCNS