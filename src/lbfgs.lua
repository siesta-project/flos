
--[[ 
Create a table with the default parameters of 
the Optima functions that are going to be inherited.
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
   self.damp = 1.
   
   -- Initial inverse Hessian
   -- Lower values converges faster at the risk of
   -- instabilities
   -- Larger values are easier to converge
   self.invH0 = 25.

   -- Number of history points used
   self.history = 100

   -- Currently reached itteration
   self.nitt = 0

   -- Constraint variable to minimize
   -- conv_C is the convergence tolerance of the constraint
   self.tolerance_C = 0.002
   self.is_optimized = false
   
   -- Maximum change in functional allowed (cut-off)
   self.max_dP = 0.1
   
   -- Field of the functional we wish to optimize
   --
   --   P == optimization variable/functional
   --   C == constraint variable/functional (minimization)
   self.P0 = {}
   self.C0 = {}

   -- History fields of the residuals.
   -- We store the residuals of the
   --   dP == optimization variable/functional
   --   dC == constraint variable/functional (minimization)
   --   rho is the kernel of the residual dot-product
   self.dP = {}
   self.dC = {}
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
function LBFGS:correct_dP (dP)

   -- Calculate the norm for each field
   local norm = self.norm1D(dP)

   -- Calculate each elements maximum norm
   local max_norm = 0.
   for i = 1, #norm do
      max_norm = m.max(max_norm, norm[i])
   end
   
   -- Now normalize dP
   norm = self.max_dP / max_norm
   if norm < 1. then
      return dP * norm
   else
      return dP
   end
   
end

-- Add the current optimization variable and the
-- constraint variable to the history.
-- This function calculates the residuals
-- and updates the kernel of the residual dot-product.
function LBFGS:add_history (P, C)

   -- Retrieve the current itteration step.
   -- With respect to the history and total
   -- itteration count.
   local itt = self:itt()

   -- If the current itteration count is
   -- more than or equal to one, it means that
   -- we already have P0 and C0
   if itt > 0 then

      self.dP[itt] = P - self.P0
      self.dC[itt] = C - self.C0
      
      -- Calculate dot-product and store the kernel
      self.rho[itt] = 1. / self.dP[itt]:reshape(-1):dot(self.dC[itt]:reshape(-1))
      
   end
   
   -- In case we have stored too many points
   -- we should clean-up the history
   if itt > self.history then

      -- Forcing garbage collection
      table.remove(self.dP, 1)
      table.remove(self.dC, 1)
      table.remove(self.rho, 1)
	 
   end

   -- Ensure that the next itteration has
   -- the input sequence
   self.P0 = P:copy()
   self.C0 = C:copy()

end

-- Calculate the optimized variable (P) which
-- minimizes the constraint (C).
function LBFGS:next (P, C)
   
   -- Add the current iteration to the history
   self:add_history(P, C)

   -- Retrieve current itteration count
   local itt = self:itt()

   -- Create local pointers to tables
   -- (they are tables, hence by-reference)
   local dP = self.dP
   local dC = self.dC
   local rho = self.rho

   -- Create table for accumulating dot products
   local rh = {}
   
   -- Create a copy of the constraint
   local q = - C:reshape(-1)
   for i = itt, 1, -1 do
      rh[i] = rho[i] * q:dot(dP[i]:reshape(-1))
	 -- Note dC is C - C0
      q = q - rh[i] * dC[i]:reshape(-1)
   end
   local z = q / self.invH0
   -- Clean-up
   q = nil

   -- Now create the next step
   for i = 1, itt do
      -- Note dC is C - C0
      local tmp = rho[i] * dC[i]:reshape(-1):dot(z)
      z = z - dP[i]:reshape(-1) * (rh[i] + tmp)
   end
   
   -- Ensure shape
   local p = - z:reshape(C.size)
   
   -- Update step
   local dp = self:correct_dP(p) * self.damp
   
   -- Determine whether we have optimized the parameter/functional
   self:optimized(C)
   
   -- Calculate next step
   local newP
   if not self.is_optimized then
      newP = P + dp
   else
      newP = P:copy()
   end

   self.nitt = self.nitt + 1
   
   return newP
      
end

-- Function to determine whether the
-- LBFGS algorithm has converged
function LBFGS:optimized (C)
   -- Check convergence
   local norm = self.norm1D(C)

   -- Determine whether the algorithm is complete.
   self.is_optimized = true
   for i = 1, #norm do
      if norm[i] > self.tolerance_C then
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
   print("LBGFS.H0 "..tostring(1. / self.invH0))
   print("LBGFS.Tolerance "..tostring(self.tolerance_C))
   print("LBGFS.Max-dP "..tostring(self.max_dP))


end

return LBFGS
