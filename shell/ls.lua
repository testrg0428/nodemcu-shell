-- == Ls ==
-- Author: Rene K. Mueller <spiritdude@gmail.com>
-- Description: list files
--
-- History:
-- 2018/01/06: 0.0.3: default 2 columns output (filename max 32 chars anyway)
-- 2018/01/04: 0.0.2: ls with individual files
-- 2018/01/03: 0.0.1: alphabetical sorting

return function(...)
   local opts = { }
   local mo = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }
   local fl = { }
   
   -- parsing arguments
   for k,v in ipairs(arg) do
      if string.find(v,"^-%w+") then
         string.gsub(v,"-(%w+)$",function(fl) opts[fl] = 1 end)
      else 
         table.insert(fl,v);
      end
   end
   local cols = opts['1'] and 1 or opts['2'] and 2 or opts['3'] and 3 or opts['4'] and 4 or 2
   local col = { }
   local testExist = true

   function lf(f,opts,last) 
      if(opts['l']) then
         local st = file.stat(f)
         if st then 
            local bits = ""
            if st.isdir then
               bits = bits .. "d" 
            else 
               bits = bits .. "-"
            end
            bits = bits .. "rwx"   
            print(string.format("%s  %6d  %s %2d %d  %s",
               bits,
               st['size'],
               mo[tonumber(st.time['mon'])],st.time['day'],st.time['year'],
               f)
            )
         else
            print("ls: cannot access '"..f.."': no such file or directory")
         end
      else
         print(f)
      end
   end
   
   table.remove(fl,1)
   
   if #fl == 0 then
      for f,s in pairs(file.list()) do
         table.insert(fl,f)
      end
      table.sort(fl)
   else
      -- check existence (and remove from list if required)
      for i,f in ipairs(fl) do
         if not file.exists(f) then
            print("ls: cannot access '"..f.."': No such file or directory")
            table.remove(fl,i)
         end
      end
   end
   
   if(cols==1 or opts['l']) then
      for n in pairs(fl) do      -- walk through list
         lf(fl[n],opts,#fl==n)
      end
   else
      local off = #fl / cols + ((#fl % cols) > 0 and 1 or 0)
      local i = 1
      while(i <= off) do
         local l = ""
         for j=0,cols-1,1 do
            if i+off*j <= #fl then
               l = l .. string.format("%-32s",fl[i+off*j])
            end
         end
         print(l)
         i = i + 1
      end
   end
end
