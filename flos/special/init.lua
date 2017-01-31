--[[ 
Create a table with the default parameters of 
the special functions that are going to be inherited.
--]]

-- Create returning table
local ret = {}

-- Add the LBFGS optimization to the returned
-- optimization table.
ret.ForceHessian = require "flos.special.forcehessian"

return ret
