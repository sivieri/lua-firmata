local simple_dispatcher = require "simple_dispatcher"
local arduino_module = require "arduino"
local bot_module = require "bot"
local socket = require "socket"
require "posix"

sched = SimpleDispatcher()
arduino = Arduino("/dev/ttyACM0")
bot = Bot(arduino)

sched:AddRoutine(function()
                while true do
                    arduino.processInput()
                    coroutine.yield()
                end
            end)
sched:AddRoutine(function()
                local prev = 0
                local cur = 0
                while true do
                    cur = arduino.digitalRead(7)
                    if cur > 20 and prev <= 20 then
                        socket.select(nil, nil, 0.5)
                        bot.stop()
                        socket.select(nil, nil, 0.5)
                        bot.forward()
                    elseif cur > 20 and prev > 20 then
                        -- maintain course
                    elseif cur <= 20 and prev <= 20 then
                        -- maintain course
                    else
                        bot.stop()
                        socket.select(nil, nil, 0.5)
                        bot.rotate_left()
                    end
                    prev = cur
                    coroutine.yield()
                end
            end)
sched:Run()
