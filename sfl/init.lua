--[[
Wrapper for loading a lot of the sfl
tool suite.

Here we add all the necessary tools that
the sfl library allows.
--]]

local ret = {}

local function add_ret( tbl )
   for k, v in pairs(tbl) do
      ret[k] = v
   end
end

add_ret(require "sfl.base")
add_ret(require "sfl.optima")

return ret
