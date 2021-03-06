--[[
Author: Mildred Ki'Lya
http://lua-users.org/lists/lua-l/2008-11/msg00453.html
--]]

local name, static = ...

name = name or "stdin"
static = static or ""

local out = { static, " ", "char ", name, "[] = {\n  " }
if static == '' then
  out[2] = ''
end

local len = 0
local c = io.read(1)
local l = 2;
while c do
  len = len + 1
  if l + 7 > 80 then
    out[#out] = ",\n  ";
    l = 2
  end
  out[#out+1] = ("0x%02x"):format(c:byte())
  out[#out+1] = ", "
  l = l + 6
  c = io.read(1)
end
out[#out] = " };\n\n";
out[#out+1] = "int "
out[#out+1] = name
out[#out+1] = "_size = "
out[#out+1] = tostring(len)
out[#out+1] = ";\n\n"

io.write(table.concat(out))


