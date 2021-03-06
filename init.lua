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
OCNS.mNSP = require("OCNS.mNSP")
OCNS.mDIX = require("OCNS.mDIX")

OCNS.dataLinkProtocols = {OCNS.mDIX}
OCNS.networkProtocols = {OCNS.mIP, OCNS.mARP}
OCNS.transportProtocols = {OCNS.mUDP}
OCNS.sessionProtocols = {OCNS.mNSP}

-- Function decapsulateToDataLink (yes, I'm the fan of long method names)
-- Is called when interface receives a message
-- ===
-- Arguments:
-- interface (object) - interface itself
-- nodeInterface (MAC) - address of the modem that sent the message
-- version - packet version
-- payload - unserialized message paylaod
function OCNS.decapsulateToDataLink(interface, switchInteface,  version, payload)
	for i = 1, #OCNS.dataLinkProtocols do
		protocol = OCNS.dataLinkProtocols[i]
		if version == protocol.headerVersion then
			protocol.onPacketReceive(senderInterface, switchInteface, ser.unserialize(payload))
		end
	end
end
-- Function decapsulateToNetworkLayer (yes, I'm the fan of long method names)
-- Is called from data link layer
-- ===
-- Arguments:
-- Many-many-many arguments that are passed directly from "modem_message" event
function OCNS.decapsulateToNetworkLayer(_, localInterface, senderInterface, port, _, version, payload)
	for i = 1, #OCNS.networkProtocols do
		protocol = OCNS.networkProtocols[i]
		if version == protocol.headerVersion then
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
			protocol.onPacketReceive(senderAddress, port, remotePort, ser.unserialize(payload))
		end
	end
end

return OCNS
