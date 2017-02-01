
--[[ 
Create a table with the default parameters of 
the Optima functions that are going to be inherited.
--]]

-- Create returning table
local ret = {}

-- Add the LBFGS optimization to the returned
-- optimization table.
ret.LBFGS = require "flos.optima.lbfgs"
ret.Lattice = require "flos.optima.lattice"

return ret