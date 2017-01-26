
--[[ 
Create a table with the default classes for optimization.
--]]

local m = require "math"
local base = require "sfl.base"
local mc = require "sfl.middleclass.middleclass"

-- Add the LBFGS optimization to the returned
-- optimization table.
local opt = mc.class('Optimizer')

-- Typically we need a norm calculater for
-- element/vector wise norms
-- This function enables the calculation
-- of vector norms along axis
function opt.norm1D(array)
   local norm1D
   
   if base.instanceOf(array, base.Array2D) then
      -- Each field is a vector
      norm1D = array:norm()
   else
      norm1D = base.Array1D:new(array.size)
      for i = 1, #array do
	 norm[i] = m.abs(array[i])
      end
   end
   return norm1D
end

function opt.flatdot(lhs, rhs)
   return lhs:reshape(-1):dot(rhs:reshape(-1))
end


return {Optimizer = opt}
