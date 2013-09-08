Arduino Firmata for Lua
==========================

This is a porting of the [Processing library for Firmata](http://playground.arduino.cc/Interfacing/Processing) (which, by the way, needs modifications to work with Processing 2.0, but this is another story).
The arduino.lua file is the library itself, with code for reading and writing digital and analog values to and from an Arduino running a compatible version of Firmata; the code has been tested with Arduino Uno and Firmata 2.3 (distributed with Arduino IDE 1.0.5). The example simply blinks the test led (pin 13) every two seconds, and reads values from a sensor connected to the first analog pin (A0) when it changes the led status.

A coroutine dispatcher is used to wait for data coming from the serial port and sending commands at the same time (the dispatcher can be found [here](http://williamaadams.wordpress.com/2013/01/30/lua-coroutines-getting-started/)); a numeric library is needed to perform bitwise operations (the source code can be found [here](https://github.com/davidm/lua-bit-numberlua/)).

Two important observations:
* the example slightly changes when run on *Carambola*, which is a  device running OpenWRT, due to differences in how the gettimeofday system call is handled
* please, forgive any programming error: this is my first program written in Lua, so there may be mistakes well hidden somewhere...