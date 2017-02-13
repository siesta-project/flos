---
-- Implementation of the Conjugate Gradient algorithm
-- @classmod CG
-- An implementation of the conjugate gradient optimization
-- algorithm.

local m = require "math"
local mc = require "flos.middleclass.middleclass"

local optim = require "flos.optima.base"
local Line = require "flos.optima.line"
local LBFGS = require "flos.optima.lbfgs"

-- Create the CG class (inheriting the Optimizer construct)
local CG = mc.class("CG", optim.Optimizer)

function CG:initialize(tbl)
   -- Wrapper which basically does nothing..
   -- All variables are defined subsequently

   -- this is the convergence tolerance of the gradient
   self.tolerance = 0.02
   self._optimized = false
   
   -- Maximum change in functional allowed (cut-off)
   self.max_dF = 0.1

   -- Storing the previous steepest descent direction
   -- and the previous gradient
   self.G0 = nil -- the previous gradient
   self.G = nil -- the current gradient
   self.conj0 = nil -- the previous conjugate direction
   self.conj = nil -- the current conjugate direction

   -- Default line search

   -- Weight, currently not used, this is equivalent
   -- weight for all CG methods
   self.weight = 1.

   -- Method of calculating the beta constant
   self.beta = "PR"
   -- Damping factor for creating a smooth CG restart
   -- minimizing beta
   self.beta_damping = 0.8
      
   -- The restart method, currently this may be:
   --   negative (restarting when beta < 0)
   --   Powell (restart when orthogonality is low)
   self.restart = "Powell"

   -- Counter for # of iterations
   self.niter = 0

   -- Ensure we update the elements as passed
   -- by new(...)
   if type(tbl) == "table" then
      for k, v in pairs(tbl) do
	 self[k] = v
      end
   end

   if self.line == nil then
      self.line = Line:new({tolerance = self.tolerance,
			    max_dF = self.max_dF})
   end
   
   self:_correct()
end

--- Internal routine for correcting the passed options
function CG:_correct()

   -- Check beta method
   local beta = self.beta:lower()
   if beta == "pr" or beta == "p-r" or beta == "polak-ribiere" then
      self.beta = "PR"
   elseif beta == "fr" or beta == "f-r" or beta == "fletcher-reeves" then
      self.beta = "FR"
   elseif beta == "hs" or beta == "h-s" or beta == "hestenes-stiefel" then
      self.beta = "HS"
   elseif beta == "dy" or beta == "d-y" or beta == "dai-yuan" then
      self.beta = "DY"
   else
      error("flos.CG could not determine beta method.")
   end

   -- Check restart method
   local restart = self.restart:lower()
   if restart == "negative" then
      self.restart = "negative"
   elseif restart == "powell" or restart == "p" then
      self.restart = "Powell"
   else
      error("flos.CG could not determine restart method.")
   end

end


--- Reset the CG algorithm for restart purposes
-- All history will be cleared and the algorithm will restart the CG
-- optimization from scratch.
function CG:reset()
   self.niter = 0
   self.G0, self.G = nil, nil
   self.conj0, self.conj = nil, nil
   self.line
end


--- Return current iteration count
-- @return the iteration count
function CG:iteration()
   return self.niter
end

--- Add the current parameters and the gradient for those to the history
-- @param F the parameters
-- @param G the gradient for the function with the parameters `F`
function CG:add_history(F, G)

   -- Cycle data
   self.G0 = self.G
   self.conj0 = self.conj

   -- Store current data (the current conjugate direction
   -- will be updated in .optimize)
   self.G = G:copy()

end


--- Returns the optimized parameters which should minimize the function
-- with respect to the current conjugate gradient
-- @param F the parameters for the function
-- @param G the gradient for the parameters
-- @return a new set of parameters to be used for the function
function CG:optimize(F, G)

   local new = nil

   if self.G == nil then
      -- This is the first CG step

      -- cycle history
      self:add_history(F, G)

      -- Initialize the current conjugate direction with G
      self.conj = G:copy()

      -- Ensure line-search is reset
      self.line:reset()

      -- Perform line-optimization
      new = self.line:optimize(F, self.conj)

      self.niter = self.niter + 1

   elseif self.line:optimized(G) then
      -- The line-optimizer has finished and we should step the
      -- steepest descent direction.

      --print("CG new conjugate direction")
      -- We cycle the history and calculate the next steepest
      -- descent direction
      self:add_history(F, G)

      -- Calculate the next conjugate direction
      self.conj = self:conjugate()

      -- Reset line-search
      self.line:reset()

      -- Perform line-optimization
      new = self.line:optimize(F, self.conj)

      self.niter = self.niter + 1

   else

      --print("CG continue line-optimization")

      -- Continue with the line-search algorithm
      new = self.line:optimize(F, G)
			       
   end

   -- Check whether we have finalized the optimization
   -- to the given tolerance
   return new

end


--- Return the new conjugate direction
-- This will take into account how the beta-value is calculated.
-- @return the new conjugate direction
function CG:conjugate()

   -- The beta value to determine the step of the steepest descent direction
   local beta
   
   if self.beta == "PR" then
      
      beta = self.G:flatten():dot( (self.G - self.G0):flatten() ) /
	 self.G0:flatten():dot( self.G0:flatten() )
      
   elseif self.beta == "FR" then
      
      beta = self.G:flatten():dot(self.G:flatten()) /
	 self.G0:flatten():dot( self.G0:flatten() )
      
   elseif self.beta == "HS" then
      
      local d = (self.G - self.G0):flatten()
      beta = - self.G:flatten():dot(d) /
	 self.conj0:flatten():dot(d)
      
   elseif self.beta == "DY" then
      
      beta = - self.G:flatten():dot(self.G:flatten()) /
	 self.conj0:flatten():dot( (self.G - self.G0):flatten() )
      
   end

   if self.restart == "negative" then

      beta = m.max(0., beta)

   elseif self.restart == "Powell" then

      -- Here we check whether the gradient of the current iteration
      -- has "lost" orthogonality to the previous iteration
      local n = self.G:norm(0) ^ 2
      if self.G:flatten():dot( self.G0:flatten() ) / n >= 0.2 then

	 -- There is a loss of orthogonality and we restart the CG algorithm
	 beta = 0.

      end

   end

   -- Damp memory for beta (older steepest descent directions
   -- loose value over minimizations), smooth restart.
   beta = beta * self.beta_damping

   --print("CG: beta = " .. tostring(beta))

   -- Now calculate the new steepest descent direction
   return self.G + beta * self.conj0

end


--- Print some information regarding the CG algorithm
function CG:info()
   
   print("")
   if self.beta == "PR" then
      print("CG: beta method: Polak-Ribiere")
   elseif self.beta == "FR" then
      print("CG: beta method: Fletcher-Reeves")
   elseif self.beta == "HS" then
      print("CG: beta method: Hestenes-Stiefel")
   elseif self.beta == "DY" then
      print("CG: beta method: Dai-Yuan")
   end
   print("CG: Tolerance "..tostring(self.tolerance))
   print("CG: Iterations "..tostring(self.niter))

   print("CG: line search:")
   self.line:info()
   print("")

end

return CG
