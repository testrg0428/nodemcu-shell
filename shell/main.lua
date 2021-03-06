-- == NodeMCU Shell ==
-- Copyright (c) 2018 by Rene K. Mueller <spiritdude@gmail.com>
-- License: MIT License (see LICENSE file)
-- Description: adapted from telnet.lua and further extended to provide NodeMCU shell functionality
--    See http://github.com/Spiritdude/nodemcu-shell for details
--    Note: this is very experimental, telnet is a prototype interface for the shell
--
-- History:
-- 2018/02/18: 0.1.0: extended path search (*/main.lua, shell/*.lua, apps/*.lua)
-- 2018/01/30: 0.0.9: dedicated fifo per socket, arch dependent code (terrible)
-- 2018/01/16: 0.0.8: terminal.* cleaned up, to make it more consistent with console.* as well
-- 2018/01/09: 0.0.6: using console.* layer so there is no print()/node.output() calls anymore
-- 2018/01/06: 0.0.4: replacing node.output() and define dedicated print(...) 
-- 2018/01/04: 0.0.3: unpacking args at dofile()
-- 2018/01/04: 0.0.2: simple arguments passed on, proper prompt and empty input handled
-- 2018/01/03: 0.0.1: first version

if shell_srv then    -- are we called from net.up.lua *again*, if so ignore
   return
end

local VERSION = '0.1.1'

local conf = {}

if file.exists("shell/shell.conf") then
   conf = dofile("shell/shell.conf")
end

if not console then
   dofile("lib/console.lua")
end

conf.port = conf.port or 2323

shell_srv = net.createServer(net.TCP,180)
if arch=='esp8266' then
   local ip = wifi.ap.getip() or wifi.sta.getip()
   syslog.print(syslog.INFO,"nodemcu shell started on "..ip.." port "..conf.port)
else
   syslog.print(syslog.INFO,"nodemcu shell started on port "..conf.port)
end

shell_srv:listen(conf.port,function(socket)
   local fifo = { }                    -- fifo[ref][..] per socket/ref
   local fifo_drained = true

   local prompt = false
   local promptString = "% " 
   
   local state = 0

   -- they must be global in order terminal.print() to work
   local function sender(c)
      local ref = tostring(c)
      if #fifo and #fifo[ref] ~= nil and #fifo[ref] > 0 then
         c:send(table.remove(fifo[ref],1))
      else
         fifo_drained = true
         if not prompt then
            c:send(promptString)
            prompt = true
         end
      end
   end
   
   local function s_output(...)
      local s = ""
      for i,v in ipairs(arg) do
         s = s .. (i>1 and " " or "")
         s = s .. tostring(v)
      end
      local ref = tostring(socket)
      --print("[2] socket="..tostring(socket))
      if fifo[ref] == nil then
         fifo[ref] = { }
      end
      table.insert(fifo[ref],s)      -- this is where esp8266 struggles if a lot of output is arriving (heap -> 0)
      --print("fifo: "..#fifo[ref].." ("..ref.."), "..node.heap()..": "..str)
      if fifo_drained then
         fifo_drained = false
         sender(socket)
      end
   end
   
   -- console.print() prints a line, terminal.print() does not
   console.output(function(...) s_output(unpack(arg)) s_output("\r\n") end)

   -- attempt to have other apps take control of the connection (like an editor)
   -- NOTE: will soon move to lib/terminal.lua
   terminal = {
      width = conf and conf.width or 80,
      height = conf and conf.height or 24,
      print = s_output,             -- default
      receive = nil,

      output = function(f) 
         print = f
      end,

      input = function(f)
         terminal.receive = f
         if f == nil then
            prompt = false
         else
            prompt = true
         end
      end
   }
   
   local function expandFilename(v)
      if string.match(v,"[*?]") then
         local re = v
         re = string.gsub(re,"[(%(%)%.%+%-%[%]%^%$)]",function(a) return "%"..a end)
         re = string.gsub(re,"%*",".*")
         re = string.gsub(re,"%?",".")
         re = "^" .. re
         re = re .. "$"
         --print("check "..re)
         local repl = { }
         for f,s in pairs(file.list()) do
            --print("check "..f.." vs "..re)
            if string.match(f,re) then
               --print(re..": "..f)
               table.insert(repl,f)
            end
         end
         table.sort(repl)
         return repl
      else
         return nil
      end
   end

   local function processLine(l,c) 
      l = string.gsub(l,"[\n\r]*$","")
      a = { }
      local fileExpFail
      if true then                 -- argument parser
         local s = 0               -- state: 0 (default), 1 = non-space, 2 = in " string, 3 = in ' string
         local t = ""              -- current token
         local ln = string.len(l)
         for i=1,ln,1 do
            local c = string.sub(l,i,i)
            if(s == 0 and c == '"') then
              s = 2
            elseif(s == 0 and c == "'") then
              s = 3
            elseif(s == 0 and c == " ") then
              s = s
            elseif(s == 0) then
              t = t..c
              s = 1
            elseif(s == 1) then
               if(c == " ") then
                  local ex = expandFilename(t)
                  if(ex and #ex == 0) then
                     fileExpFail = "no match" -- for <"..t..">"
                  elseif ex then
                     fileExpFail = nil
                     for i,v in ipairs(ex) do
                        table.insert(a,v)
                     end
                  else
                     table.insert(a,t)
                  end
                  t = ""
                  s = 0
               else
                  t = t..c;
               end
            elseif(s == 2) then
               if(c == '"') then
                  table.insert(a,t)
                  t = ""
                  s = 0
              else
                  t = t..c;
              end
            elseif(s == 3) then
               if(c == "'") then
                  table.insert(a,t)
                  t = ""
                  s = 0
               else
                  t = t..c;
               end
             end
         end
         
         if(string.len(t) > 0) then
            if(s == 1) then
               local ex = expandFilename(t)
               if(ex and #ex == 0) then
                  fileExpFail = "no match" -- for <"..t..">"
               elseif ex then
                  fileExpFail = nil
                  for i,v in ipairs(ex) do
                     table.insert(a,v)
                  end
               else
                  table.insert(a,t)
               end
            else
               table.insert(a,t)
            end
         end
      else
         -- crude space separating arguments (no strings ".." or '..' parsed)
         string.gsub(l,"([^ ]+)",function(c) 
            a[#a+1] = c
            --print("="..c)    
          end)
      end

      if(#a > 0 and fileExpFail) then
         --c:send(a[1]..": "..fileExpFail.."\n")
         c:send(promptString)
         prompt = true
      elseif #a > 0 then
         local cmd = a[1]
         cmd = string.gsub(cmd,"[^a-zA-Z_0-9%-/]","")     -- clean up command
         --print("process "..cmd)
         --socket = c              -- clumsy switch to correct socket
         local st,err,f
         if cmd=='exit' then
            prompt = true     -- don't try to print it 
            c:close()
            return
         else
            local done = false
            local types = { '' }
            if arch=='esp32' then
               types = { '32', '' }
            end
            local f
            for j,loc in pairs({"shell/"..cmd, cmd.."/main", "apps/"..cmd}) do
               for k,kind in pairs({".lc", ".lua"}) do
                  for i,type in pairs(types) do
                     if file.exists(loc..type..kind) then
                        --print("execute "..loc..type..kind)
                        f = dofile(loc..type..kind)
                        done = true
                     end
                     if done then break end
                  end
                  if done then break end
               end
               if done then break end
            end
            if f and type(f)=='function' then
               f(unpack(a))
            end
            if done ~= true then
               console.print("ERROR: command <"..cmd.."> not found")
            end
         end
         if not st and err then
            console.print("ERROR: "..err)
         end
         if not terminal.receive then
            prompt = false
            sender(c)
         end
         collectgarbage()
      else
         c:send(promptString)
         prompt = true
      end
   end
   
   socket:on("connection",function(c)
      -- c:send(string.format("%c%c%c%c%c%c%c%c%c",255,251,34,255,252,3,255,252,1)) -- linemode
      -- if we send, we need to process response too in on:("receive")
      if arch == 'esp8266' then                 -- esp32 struggles to get response
         c:send(string.format("%c%c%c",255,253,31))
            -- will reply 255 251 31 & 255 250 31 0 <width> 0 <height> 255 240
      end
      state = 1
   end)
   
   local line = ""
   local _buff = ""
   
   socket:on("receive",function(c,l)      -- we receive line-wise input
      collectgarbage()
      if arch ~= 'esp8266' then           -- if esp32 then go to state 2 right away (no probing of console-window size)
         state = 2
      end
      if state == 1 then                  -- process reply from client, width & height
         _buff = _buff .. l
         local m = "\255\250\031\000";
         local sp, se = string.find(_buff,m)       -- we can't string.match(_buff,"\xff\xfa\x1f\x00(.)\x00(.)\xff\xf0")
         if sp and se then
            terminal.width = string.byte(_buff,se+1)
            terminal.height = string.byte(_buff,se+3)
            state = 2
            _buff = nil
            collectgarbage()
         end
      elseif state == 2 then
         --console.print("[1]socket="..tostring(socket))
         if terminal.receive then
            terminal.receive(l,c)
         elseif(false or conf.port == 23) then
            line = line .. l
            console.print("'"..line.."'")
            if string.match(line,"[\x0d\r\n]$") then
               processLine(line,c)
               line = ""
            end
         else
            processLine(l,c)
         end
         collectgarbage()
      end
   end)

   socket:on("disconnection",function(c)
      socket = nil
      collectgarbage()
   end)

   socket:on("sent",sender)      -- handle fifo 

   local ms = ""
   if conf and conf.banner and file.exists("shell/bnr."..arch.."."..(conf and conf.banner_type or 'bw')..".txt") then
      dofile("shell/cat.lua")('cat',"shell/bnr."..arch.."."..(conf and conf.banner_type or 'bw')..".txt")
   else
      ms = "\n== "
   end
   ms = ms .. "Welcome to NodeMCU Shell " .. VERSION .. "/" .. arch .. " on "

   if wifi and wifi.sta and wifi.sta.gethostname then
      ms = ms .. wifi.sta.gethostname().." ("..node.chipid()..string.format("/0x%x",node.chipid())..")"
   else 
      ms = ms .. "("..node.chipid()..string.format("/0x%x",node.chipid())..")"
   end
   console.print(ms.."\n")
end)
