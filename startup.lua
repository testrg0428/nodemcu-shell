-- add action done at boot/startup
dofile("lib/syslog.lua")
syslog.print(syslog.INFO,"device "..node.chipid()..string.format(" / 0x%x",node.chipid()).." starting up")
dofile("display/init.lua")
dofile("wifi/init.lua")

-- a slight delay in case startup/* script resets device, we can overwrite something (interrupt reboot loop)
tmr.create():alarm(5000,tmr.ALARM_SINGLE,function()
   if true then      -- experimental
      for f in pairs(file.list()) do
         if f.match(f,"^startup/") then
            syslog.print(syslog.INFO,"startup: execute "..f)
            dofile(f)
         end
      end
   end
end)
