package.cpath = package.cpath .. ";/usr/local/lib/?.so"
rs232 = require "luars232"
bit = require "bit.numberlua"
socket = require "socket"

function write_format(little_endian, format, ...)
  local res = ''
  local values = {...}
  for i=1,#format do
    local size = tonumber(format:sub(i,i))
    local value = values[i]
    local str = ""
    for j=1,size do
      str = str .. string.char(value % 256)
      value = math.floor(value / 256)
    end
    if not little_endian then
      str = string.reverse(str)
    end
    res = res .. str
  end
  return res
end

function read_format(little_endian, format, str)
  local idx = 0
  local res = {}
  for i=1,#format do
    local size = tonumber(format:sub(i,i))
    local val = str:sub(idx+1,idx+size)
    local value = 0
    idx = idx + size
    if little_endian then
      val = string.reverse(val)
    end
    for j=1,size do
      value = value * 256 + val:byte(j)
    end
    res[i] = value
  end
  return unpack(res)
end

function readonlytable(table)
    return setmetatable({}, {
        __index = table,
        __newindex = function(table, key, value)
                    error("Attempt to modify read-only table")
                    end,
        __metatable = false
    });
end

ArduinoConstants = readonlytable {
    INPUT = 0,
    OUTPUT = 1,
    LOW = 0,
    HIGH = 1,
    MAX_DATA_BYTES = 32,
    DIGITAL_MESSAGE = 0x90,
    ANALOG_MESSAGE = 0xE0,
    REPORT_ANALOG = 0xC0,
    REPORT_DIGITAL = 0xD0,
    SET_PIN_MODE = 0xF4,
    REPORT_VERSION = 0xF9,
    SYSTEM_RESET = 0xFF,
    START_SYSEX = 0xF0,
    END_SYSEX = 0xF7
}

function Arduino(port_name)
    
    local self = {
        -- public fields
    }

    -- private fields
    local waitForData = 0
    local executeMultiByteCommand = 0
    local multiByteChannel = 0
    local storedInputData = { }
    local parsingSysex = false
    local sysexBytesRead = 0
    local digitalOutputData = { }
    local digitalInputData = { }
    local analogInputData = { }
    local majorVersion = 0
    local minorVersion = 0
    local out = io.stderr
    
    -- serial port
    local e, p = rs232.open(port_name)
    if e ~= rs232.RS232_ERR_NOERROR then
        -- handle error
        out:write(string.format("can't open serial port '%s', error: '%s'\n",
                port_name, rs232.error_tostring(e)))
        return
    end
    assert(p:set_baud_rate(rs232.RS232_BAUD_57600) == rs232.RS232_ERR_NOERROR)
    assert(p:set_data_bits(rs232.RS232_DATA_8) == rs232.RS232_ERR_NOERROR)
    assert(p:set_parity(rs232.RS232_PARITY_NONE) == rs232.RS232_ERR_NOERROR)
    assert(p:set_stop_bits(rs232.RS232_STOP_1) == rs232.RS232_ERR_NOERROR)
    assert(p:set_flow_control(rs232.RS232_FLOW_OFF)  == rs232.RS232_ERR_NOERROR)
    out:write(string.format("OK, port open with values '%s'\n", tostring(p)))
    
    --initialize arrays starting from zero, for god's sake!
    for i = 0, 32, 1 do
        storedInputData[i] = 0
    end
    for i = 0, 16, 1 do
        digitalInputData[i] = 0
        digitalOutputData[i] = 0
        analogInputData[i] = 0
    end
    
    -- initialize Firmata
    socket.sleep(2)
    for i = 0, 6, 1 do
        p:write(write_format(true, "1", bit.bor(ArduinoConstants.REPORT_ANALOG, i)))
        p:write(write_format(true, "1", 1))
    end
    for i = 0, 2, 1 do
        p:write(write_format(true, "1", bit.bor(ArduinoConstants.REPORT_DIGITAL, i)))
        p:write(write_format(true, "1", 1))
    end
    p:flush()

    -- functions
    function self.digitalRead(pin)
        return bit.band((bit.rshift(digitalInputData[bit.rshift(pin, 3)], (bit.band(pin, 0x07)))), 0x01)
    end
    
    function self.analogRead(pin)
        return analogInputData[pin]
    end

    function self.pinMode(pin, mode)
        p:write(write_format(true, "1", ArduinoConstants.SET_PIN_MODE))
        p:write(write_format(true, "1", pin))
        p:write(write_format(true, "1", mode))
        p:flush()
    end

    function self.digitalWrite(pin, value)
        local portNumber = bit.band(bit.rshift(pin, 3), 0x0F)
        if value == 0 then
            digitalOutputData[portNumber] = bit.band(digitalOutputData[portNumber], bit.bnot(bit.lshift(1, bit.band(pin, 0x07))))
        else
            digitalOutputData[portNumber] = bit.bor(digitalOutputData[portNumber], bit.lshift(1, bit.band(pin, 0x07)))
        end
        p:write(write_format(true, "1", bit.bor(ArduinoConstants.DIGITAL_MESSAGE, portNumber)))
        p:write(write_format(true, "1", bit.band(digitalOutputData[portNumber], 0x7F)))
        p:write(write_format(true, "1", bit.rshift(digitalOutputData[portNumber], 7)))
        p:flush()
    end

    function self.analogWrite(pin, value)
        p:write(write_format(true, "1", bit.bor(ArduinoConstants.ANALOG_MESSAGE, bit.band(pin, 0x0F))))
        p:write(write_format(true, "1", bit.band(value, 0x7F)))
        p:write(write_format(true, "1", bit.rshift(value, 7)))
        p:flush()
    end
    
    function self.setDigitalInputs(portNumber, portData)
        digitalInputData[portNumber] = portData
    end
    
    function self.setAnalogInput(pin, value)
        analogInputData[pin] = value
    end
    
    function self.setVersion(major, minor)
        majorVersion = major
        minorVersion = minor
    end
    
    function self.processInput()
        local command
        local read_len = 1 -- read one byte
        local timeout = 10 -- in milliseconds
        local err, inputString, size = p:read(read_len, timeout)
        local inputData = 0
        assert(err == rs232.RS232_ERR_NOERROR or err == rs232.RS232_ERR_TIMEOUT)
        if size > 0 then
            inputData = read_format(true, "1", inputString)
            if parsingSysex then
                if inputData == ArduinoConstants.END_SYSEX then
                    parsingSysex = false
                else
                    storedInputData[sysexBytesRead] = inputData
                    sysexBytesRead = sysexBytesRead + 1
                end
            elseif waitForData > 0 and inputData < 128 then
                waitForData = waitForData - 1
                storedInputData[waitForData] = inputData
                if executeMultiByteCommand ~= 0 and waitForData == 0 then
                    if executeMultiByteCommand == ArduinoConstants.DIGITAL_MESSAGE then
                        self.setDigitalInputs(multiByteChannel, bit.lshift(storedInputData[0], 7) + storedInputData[1])
                    elseif executeMultiByteCommand == ArduinoConstants.ANALOG_MESSAGE then
                        self.setAnalogInput(multiByteChannel, bit.lshift(storedInputData[0], 7) + storedInputData[1])
                    elseif executeMultiByteCommand == ArduinoConstants.REPORT_VERSION then
                        self.setVersion(storedInputData[1], storedInputData[0])
                    end
                end
            else
                if inputData < 0xF0 then
                    command = bit.band(inputData, 0xF0)
                    multiByteChannel = bit.band(inputData, 0x0F)
                else
                    command = inputData
                end
                if command == ArduinoConstants.DIGITAL_MESSAGE or command == ArduinoConstants.ANALOG_MESSAGE or command == ArduinoConstants.REPORT_VERSION then
                    waitForData = 2
                    executeMultiByteCommand = command
                end
            end
        end
    end
    
    -- return the instance
    return self
end
