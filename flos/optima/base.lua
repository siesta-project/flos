
--[[ 
Create a table with the default classes for optimization.
--]]

local mc = require "flos.middleclass.middleclass"

-- Add the LBFGS optimization to the returned
-- optimization table.
local opt = mc.class('Optimizer')

return {Optimizer = opt}
