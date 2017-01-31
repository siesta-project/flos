
--[[ 
Create a table with the default classes for optimization.
--]]

local m = require "math"
local base = require "flos.base"
local mc = require "flos.middleclass.middleclass"

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
      norm1D = array:abs()
   end
   return norm1D
end

function opt.flatdot(lhs, rhs)
   return lhs:reshape(-1):dot(rhs:reshape(-1))
end


return {Optimizer = opt}
