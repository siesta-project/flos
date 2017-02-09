
--[[ 
Create a table with the default classes for optimization.
--]]

local mc = require "flos.middleclass.middleclass"

-- Add the LBFGS optimization to the returned
-- optimization table.
local opt = mc.class('Optimizer')

-- Function to determine whether the an algorithm has converged
function opt:optimized(G)
   
   -- Check convergence
   local norm
   if #G.shape == 1 then
      -- the absolute value is the requested quantity
      norm = G:abs():max()
   else
      norm = G:norm():max()
   end

   -- Determine whether the algorithm is complete.
   self.is_optimized = norm < self.tolerance

   return self.is_optimized
   
end


return {Optimizer = opt}
