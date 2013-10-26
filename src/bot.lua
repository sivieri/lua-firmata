local arduino_module = require "arduino"
local socket = require "socket"

function Bot(arduino)
    
    local self = {
        -- public fields
    }
    
    arduino.pinMode(3, ArduinoConstants.PWM)
    arduino.pinMode(11, ArduinoConstants.PWM)
    arduino.pinMode(12, ArduinoConstants.OUTPUT)
    arduino.pinMode(13, ArduinoConstants.OUTPUT)
    
    -- functions
    function self.forward()
        arduino.digitalWrite(12, ArduinoConstants.HIGH)
        arduino.digitalWrite(13, ArduinoConstants.HIGH)
        arduino.analogWrite(3, 255)
        arduino.analogWrite(11, 255)
    end

    function self.stop()
        arduino.digitalWrite(12, ArduinoConstants.LOW)
        arduino.digitalWrite(13, ArduinoConstants.LOW)
        socket.select(nil, nil, 0.1)
        arduino.analogWrite(3, 0)
        arduino.analogWrite(11, 0)
        arduino.digitalWrite(12, ArduinoConstants.HIGH)
        arduino.digitalWrite(13, ArduinoConstants.HIGH)
    end

    function self.rotate_left()
        arduino.digitalWrite(12, ArduinoConstants.LOW)
        arduino.digitalWrite(13, ArduinoConstants.HIGH)
        arduino.analogWrite(3, 200)
        arduino.analogWrite(11, 200)
    end
    
    -- return the instance
    return self
end
