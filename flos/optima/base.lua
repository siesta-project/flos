---
-- Basic optimization class that is to be inherited by all the
-- optimization classes.
-- @classmod Optimizer
-- The basic class used for optimization routines.

local mc = require "flos.middleclass.middleclass"

-- Add the LBFGS optimization to the returned
-- optimization table.
local Optimizer = mc.class('Optimizer')

--- Initialization routine for all optimizers
function Optimizer:initialize()

   -- Currently reached iteration
   self.niter = 0

   -- Specify the maximum step of the variables
   self.max_dF = 0.1
   
   -- this is the convergence tolerance of the gradient
   self.tolerance = 0.02

   -- Whether the optimization algorithm has been optimized
   self._optimized = false

end

--- Reset default variables, such as the number of iterations
function Optimizer:reset()
   self.niter = 0
end


--- Query number of iterations this method has runned
-- @return number of iterations this optimization method has runned
function Optimizer:iteration()
   return self.niter
end


--- Check whether the optimization routine has been optimized
-- such that the maximum vector norm of the gradient is below
-- a given tolerance.
-- @Array[opt] G the gradient to check for convergence
-- @return a boolean of whether the gradient is below the tolerance
--    if `G` is `nil`, it returns the last status of this function
--    call.
function Optimizer:optimized(G)

   -- Return stored optimized quantity if G is not
   -- passed
   if G == nil then
      return self._optimized
   end
   
   -- Check convergence
   local norm
   if #G.shape == 1 then
      -- the absolute value is the requested quantity
      norm = G:abs():max()
   else
      norm = G:norm():max()
   end

   -- Determine whether the algorithm is complete.
   self._optimized = norm < self.tolerance

   return self._optimized
   
end

-- Return table
return {Optimizer = Optimizer}
