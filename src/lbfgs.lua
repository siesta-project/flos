--[[ 
This module implements the L-BFGS algorithm
for minimization of a functional with an accompanying
gradient.
--]]

local m = require "math"
local mc = require "middleclass.middleclass"
local optim = require "optima_base"

-- Create the LBFGS class (inheriting the Optimizer construct)
local LBFGS = mc.class("LBFGS", optim.Optimizer)

function LBFGS:initialize(...)
   -- Wrapper which basically does nothing..
   -- All variables are defined subsequently

   -- Damping of the BFGS algorithm
   --  damp > 1
   --    over-relaxed
   --  damp < 1
   --    under-relaxed
   self.damp = 1.1
   
   -- Initial inverse Hessian
   -- Lower values converges faster at the risk of
   -- instabilities
   -- Larger values are easier to converge
   self.H0 = 1. / 25.

   -- Number of history points used
   self.history = 100

   -- Currently reached itteration
   self.nitt = 0

   -- this is the convergence tolerance of the gradient
   self.tolerance = 0.02
   self.is_optimized = false
   
   -- Maximum change in functional allowed (cut-off)
   self.max_dF = 0.1
   
   -- Field of the functional we wish to optimize
   --
   --   F == optimization variable/functional
   --   G == gradient variable/functional (minimization)
   self.F0 = {}
   self.G0 = {}

   -- History fields of the residuals.
   -- We store the residuals of the
   --   dF == optimization variable/functional
   --   dG == gradient variable/functional (minimization)
   --   rho is the kernel of the residual dot-product
   self.dF = {}
   self.dG = {}
   self.rho = {}

   -- Ensure we update the elements as passed
   -- by new(...)
   local arg = {...}
   for k, v in pairs(arg) do
      self[k] = v
   end
   
end

-- Function to return the current itteration count
function LBFGS:itt ()
   return m.min(self.nitt, self.history)
end

-- Correct the step-size (change of optimization variable)
-- by asserting that the norm of each vector is below
-- a given threshold.
function LBFGS:correct_dF (dF)

   -- Calculate the norm for each field
   local norm = self.norm1D(dF)

   -- Calculate each elements maximum norm
   local max_norm = 0.
   for i = 1, #norm do
      max_norm = m.max(max_norm, norm[i])
   end
   
   -- Now normalize the displacement
   norm = self.max_dF / max_norm
   if norm < 1. then
      return dF * norm
   else
      return dF
   end
   
end

-- Add the current optimization variable and the
-- gradient variable to the history.
-- This function calculates the residuals
-- and updates the kernel of the residual dot-product.
function LBFGS:add_history (F, G)

   -- Retrieve the current itteration step.
   -- With respect to the history and total
   -- itteration count.
   local itt = self:itt()

   -- If the current itteration count is
   -- more than or equal to one, it means that
   -- we already have F0 and G0
   if itt > 0 then

      self.dF[itt] = F - self.F0
      self.dG[itt] = G - self.G0
      
      -- Calculate dot-product and store the kernel
      self.rho[itt] = 1. / self.dF[itt]:reshape(-1):dot(self.dG[itt]:reshape(-1))
      
   end
   
   -- In case we have stored too many points
   -- we should clean-up the history
   if itt > self.history then

      -- Forcing garbage collection
      table.remove(self.dF, 1)
      table.remove(self.dG, 1)
      table.remove(self.rho, 1)
	 
   end

   -- Ensure that the next itteration has
   -- the input sequence
   self.F0 = F:copy()
   self.G0 = G:copy()

end

-- Calculate the optimized variable (F) which
-- minimizes the gradient (G).
function LBFGS:next (F, G)
   
   -- Add the current iteration to the history
   self:add_history(F, G)

   -- Retrieve current itteration count
   local itt = self:itt()

   -- Create local pointers to tables
   -- (they are tables, hence by-reference)
   local dF = self.dF
   local dG = self.dG
   local rho = self.rho

   -- Create table for accumulating dot products
   local rh = {}
   
   -- Update the uphill gradient
   local q = G:reshape(-1)
   for i = itt, 1, -1 do
      rh[i] = rho[i] * dF[i]:reshape(-1):dot(q)
      q = q - rh[i] * dG[i]:reshape(-1)
   end

   -- Solve for the rhs optimization
   local z = q * self.H0
   -- Clean-up
   q = nil

   -- Now create the next step
   for i = 1, itt do
      local beta = rho[i] * dG[i]:reshape(-1):dot(z)
      z = z + dF[i]:reshape(-1) * (rh[i] - beta)
   end
   
   -- Ensure shape
   z = - z:reshape(G.size)
   
   -- Update step
   local delta = self:correct_dF(z) * self.damp
   
   -- Determine whether we have optimized the parameter/functional
   self:optimized(G)
   
   -- Calculate next step
   local newF
   if not self.is_optimized then
      newF = F + delta
   else
      newF = F:copy()
   end

   self.nitt = self.nitt + 1
   
   return newF
      
end

-- Function to determine whether the
-- LBFGS algorithm has converged
function LBFGS:optimized (G)
   -- Check convergence
   local norm = self.norm1D(G)

   -- Determine whether the algorithm is complete.
   self.is_optimized = true
   for i = 1, #norm do
      if norm[i] > self.tolerance then
	 self.is_optimized = false
      end
   end
   
end

-- Print information regarding the LBFGS algorithm
function LBFGS:info ()
   
   if self.nitt == 0 then
      print("Welcome to LBFGS algorithm...")
   end
   
   print("LBGFS current / history: "..tostring(self:itt()) .. " / "..self.history)
   print("LBGFS.damping "..tostring(self.damp))
   print("LBGFS.H0 "..tostring(self.H0))
   print("LBGFS.Tolerance "..tostring(self.tolerance))
   print("LBGFS.max-dF "..tostring(self.max_dF))


end

return LBFGS
