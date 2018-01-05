# NodeMCU UNIX-like Shell

** Highly Experimental: API and Skeleton might change at any time **

This provides a UNIX-like Shell for the NodeMCU platform (ESP8266: 32KB RAM, 512K-16MB flash, 80MHz RISC Processor with WIFI, cost ~ USD/EUR 2.00-5.00).

NodeMCU is a LUA runtime environment, so the "shell" is written in LUA.

Example:
```
> telnet 192.168.2.119 2323
Trying 192.168.2.119...
Connected to 192.168.2.119.
Escape character is '^]'.
== Welcome to NodeMCU Shell 0.0.4
% ls -l
/
-rwx     258  Jan  1 1970  args/main.lua
-rwx      59  Jan  1 1970  args2/main.lua
-rwx     540  Jan  1 1970  blink/main.lua
-rwx    1108  Jan  1 1970  compile/main.lua
-rwx      81  Jan  1 1970  init.lua
-rwx      30  Jan  1 1970  net.down.lua
-rwx      76  Jan  1 1970  net.up.lua
-rwx    1359  Jan  1 1970  rtc/init.lua
-rwx     327  Jan  1 1970  shell/cat.lua
-rwx     771  Jan  1 1970  shell/cp.lua
-rwx     476  Jan  1 1970  shell/date.lua
-rwx     537  Jan  1 1970  shell/df.lua
-rwx     246  Jan  1 1970  shell/dofile.lua
...
                         
% df
Filesystem    Total    Used   Avail.   Use%  Mounted On
/flashfs      3322738  26606  3296132  0%    /

% uptime
0d 0h 46m 51s

% cat startup.lua
-- add action done at boot/startup
dofile("wifi/wifi.lua")

% help
available commands:
   args
   blink
   cat
   compile
   cp
   date
   df
   dofile
   echo
   exit
   heap
   help
   hostname
   ls
   lua
   mv
   ping
   reboot
   rm
   sysinfo
   time
   touch
   uptime

% exit
Connection closed by foreign host.
```

## Layout of Commands

Following filesystem layout has been adopted:
- every command or app has its own directory or namespace, with main entry point of `<appname>/main.lua`
- every shell built-in command resides in `shell/<command>.lua`
- each `main.lua` or `shell/<command>.lua` must conform to following skeleton:

```
return function(...) 
   -- arg[1] contains the command name itself (e.g. 'ls')
   -- arg[2] optionally contains the first argument (e.g. `ls a.lua` then arg[2] = "a.lua")
   -- etc.
end
```

`shell/main.lua` is the NodeMCU shell main entry, it opens a telnet server at port 2323 (default).

## Network Configuration

At first you need to configure `wifi/wifi.conf`, first copy `wifi/wifi.conf.dist` to `wifi/wifi.conf` and edit it:
```
return {
   mode = "client",     -- "client" or "ap"
   client = {
      ssid = "yourWIFI"
      password = "youWIFIpassword"
   },
   ap = { 
      config = {
         ssid = "ESP-"..node.chipid(),
         pwd = "Pass"..node.chipid()
      },
      net = {
         ip = "192.168.111.1",
         netmask = "255.255.255.255",
         gateway = "192.168.111.1"
      }
   }
}
```

Either have the device join your existing WIFI, edit then part of "client" part, or let the device operate as access point (AP) then change "mode" to "ap", and keep the defaults otherwise.

## Requirements
Install `nodemcu-tool` via
```
sudo npm install nodemcu-tool -g
```

## Firmware
The recommended modules for your firmware from [nodemcu-build.com](https://nodemcu-build.com):
- **adc** (recommended)
- **bit**
- **crypto**
- **encoder**
- **file**
- **gpio**
- **http**
- **i2c** (recommended)
- **mdns**
- **mqtt** (recommended)
- **net**
- **node**
- **rtctime**
- **sjson**
- **sntp** (recommended)
- **struct**
- **tmr**
- **u8g** (monochrome) or **ucg** (color): if you have a display attached, then add module **spi** as well
- **uart**
- **websocket** (recommended)
- **wifi**
- **tls** (enable it after the list of the modules)

Install proper firmware with `esptool.py` or other flashing tool.

## Installation
To install the shell with its own `init.lua` and `startup.lua` chain:
```
% make upload_all
```

which uploads the entire setup to your NodeMCU/ESP8266 device.

If your device resides somewhere else than the default (`/dev/ttyUSB0`), set it with `PORT=<device>`, for example:
```
% make PORT=/dev/ttyUSB4 upload_all
```

Once all uploaded fine, you reset the device.

Preferably start a terminal to see the NodeMCU console:
```
% nodemcu-tool --port /dev/ttyUSB0 terminal
```

Once your device becomes available via WIFI (as client or access point), you see the IP in the console, then you can telnet to it, for example:
```
% telnet 192.168.2.119 2323
Trying 192.168.2.119...
Connected to 192.168.2.119.
Escape character is '^]'.
== Welcome to NodeMCU Shell 0.0.3
% help
available commands:
   ...
   ...
   
% cat init.lua
-- DO NOT CHANGE
if file.exists("startup.lua") then
   dofile("startup.lua")
end

% cat startup.lua
-- add action done at boot/startup
dofile("wifi/wifi.lua")

% cat net.up.lua
-- do things when net is up
dofile("rtc/init.lua")
dofile("shell/main.lua")

% 
```

Type in 'help' and hit RETURN and it will list the available commands.

## LS
## CAT
## ECHO
## MV
## RM
## CP
## TOUCH
## DF
## BLINK
## HEAP
## UPTIME
## DATE
## HOSTNAME
## TIME
## SYSINFO
## PING
## COMPILE
## ARGS
Display arguments:
```
% args "abc def" 5 14
1 = 'args'
2 = 'abc def'
3 = '5'
4 = '14'
```
## DOFILE
Execute a .lua file via `dofile()`:
```
% dofile example.lua
``
## LUA
Execute actual LUA code:
```
% lua print("abc")
abc

% lua print(node.bootreason())
2     6
```
## REBOOT
```
% reboot
```
### EXIT
This is a built-in command (there is no corresponding .lua) and disconnects telnet session:
```
% exit
Connection closed by foreign host.
```
