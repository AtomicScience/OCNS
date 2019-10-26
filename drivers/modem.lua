local component = require("component")
local ser = require("serialization")
local event = require("event")

-- modem interface driver
local modem  = {}

modem.isListenerRegistered = false
-- List of all intefaces of certain type
modem.interfaces = {}
-- Amount of modem in the system. Is used only for generating labels for drivers.
modem.count = 0
-- Function newInstance
-- Creates an object of the interface
-- ===
-- Arguments:
-- address (string) - address of the component that you want to drive
-- label (string) - label of the interface
function modem.newInstance(address)
  local obj= {}

  -- Required fields. Don't forget to define them in your own drivers
  -- Type of the driver (REQUIRED FIELD FOR DRIVER OBJECT)
  obj.type = "modem"
  -- Label of our interface (REQUIRED FIELD FOR DRIVER OBJECT)
  obj.label = "eth"
  -- Optional description (REQUIRED FIELD FOR DRIVER OBJECT)
  obj.description = "description"
  -- Physical address of the modem related to the driver (REQUIRED FIELD FOR DRIVER OBJECT)
  obj.physicalAddress = ""
  -- mARP protocol settings (REQUIRED FIELD FOR DRIVER OBJECT)
  obj.mARP = {
    -- mARP table
    table = {},
    -- Timeout of mARP record in seconds
  	recordTimeout = 300,
  	-- Timeout of mARP request in seconds
  	requestTimeout = 2
  }
  -- mIP protocol settings (REQUIRED FIELD FOR DRIVER OBJECT)
  obj.mIP = {
    address = 0
  }
  -------
  -- Adding a physical address
  obj.physicalAddress = address

  -- Registering a proxy to simplify component access
  obj.modem = component.proxy(address)

  -- Adding a label for our driver
  obj.label = "eth" .. modem.count
  modem.count = modem.count + 1

  -- Adding a description for the driver
  if obj.modem.isWireless() then
    obj.description = "Wireless Ethernet modem"
  else
    obj.description = "Ethernet modem"
  end

  -- function send (REQUIRED FUNCTION FOR DRIVER OBJECT)
  -- Sends a data - just sets it at media via broadcast
  function obj:send(port, version, payload)
    self.modem.broadcast(port, version, ser.serialize(payload))
  end

  -- function openPort
  -- Opens a specified port
  function obj:openPort(port)
    self.modem.openPort(port)
  end

  -- function closePort
  -- Opens a specified port
  function obj:closePort(port)
    self.modem.closePort(port)
  end

  -- function closePort
  -- Checks if port specified is open or not
  function obj:isOpen(port)
    return self.modem.isOpen(port)
  end

  -- IDK what does it do. Pure magic!
  setmetatable(obj, modem)
  modem.__index = modem; return obj
end

-- Function init (REQUIRED FUNCTION FOR DRIVER OBJECT)
-- Creates drivers for all the related components in the system
-- =====
-- Returns
-- table of drivers - drivers registerd
function modem.init()
  modem.count = 0
  local ret = {}
  -- Iterating all the 'modem' components
  for address, _ in component.list("modem", true) do
      table.insert(ret, modem.newInstance(address))
  end

  -- Registering an event handler
  if not modem.isListenerRegistered then
    event.listen("modem_message", modem.onModemMessage)
    modem.isListenerRegistered = true
  end

  modem.interfaces = ret

  return ret
end

-- Function onModemMessage
-- A handler for incoming modem messages
function modem.onModemMessage(_, localInterface, senderInterface, port, _, version, payload)
  for i = 1, #modem.interfaces do
    if localInterface == modem.interfaces[i].physicalAddress then
      require("OCNS").decapsulateToDataLink(modem.interfaces[i], localInterface, version, ser.unserialize(payload))
    end
  end
end

return modem
