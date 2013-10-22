local simple_dispatcher = require "simple_dispatcher"
local arduino_module = require "arduino"
local socket = require "socket"
require "posix"

sched = SimpleDispatcher()
arduino = Arduino("/dev/ttyACM0")
arduino.pinMode(13, ArduinoConstants.OUTPUT)
sched:AddRoutine(function()
                while true do
                    arduino.processInput()
                    coroutine.yield()
                end
            end)
sched:AddRoutine(function()
                local last = 0
                local cur = 0
                local status = false
                while true do
                    -- on OpenWRT (Carambola, Arduino Yun...):
                    -- cur = posix.gettimeofday()
                    cur = posix.gettimeofday()["sec"]
                    if cur % 2 == 0 and cur ~= last then
                        if status then
                            arduino.digitalWrite(13, ArduinoConstants.LOW)
                            status = false
                        else
                            arduino.digitalWrite(13, ArduinoConstants.HIGH)
                            status = true
                        end
                        last = cur
                        print("LED changed")
                        print(arduino.analogRead(0))
                    end
                    coroutine.yield()
                end
            end)
sched:Run()
