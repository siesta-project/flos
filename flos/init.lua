--[[
Wrapper for loading a lot of the flos
tool suite.

Here we add all the necessary tools that
the flos library allows.
--]]

local ret = {}

local function add_ret( tbl )
   for k, v in pairs(tbl) do
      ret[k] = v
   end
end

add_ret(require "flos.base")
add_ret(require "flos.array")
-- LBFGS algorithm and other optimizers
add_ret(require "flos.optima")
-- ForceHessian MD method and other methods
add_ret(require "flos.special")

return ret
