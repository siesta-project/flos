--[[ 
This module implements the L-BFGS algorithm
for minimization of a functional with an accompanying
gradient.
--]]

local m = require "math"
local mc = require "flos.middleclass.middleclass"
local optim = require "flos.optima.base"

-- Create the LBFGS class (inheriting the Optimizer construct)
local LBFGS = mc.class("LBFGS", optim.Optimizer)

function LBFGS:initialize(tbl)
   -- Wrapper which basically does nothing..
   -- All variables are defined subsequently

   -- Damping of the BFGS algorithm
   --  damping > 1
   --    over-relaxed
   --  damping < 1
   --    under-relaxed
   self.damping = 1.0
   
   -- Initial inverse Hessian
   -- Lower values converges faster at the risk of
   -- instabilities
   -- Larger values are easier to converge
   self.H0 = 1. / 25.

   -- Number of history points used
   self.history = 100

   -- Currently reached iteration
   self.niter = 0

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
   -- The last G . dF using dF for the optimized step
   self.rho_optimized = 0.

   -- Ensure we update the elements as passed
   -- by new(...)
   if type(tbl) == "table" then
      for k, v in pairs(tbl) do
	 self[k] = v
      end
   end
end

-- Reset the algorithm
-- Basically all variables that
-- are set should be reset
function LBFGS:reset()
   self.niter = 0
   self.F0 = {}
   self.G0 = {}
   self.dF = {}
   self.dG = {}
   self.rho = {}
   self.rho_optimized = 0.
end

-- Function to return the current iteration count
function LBFGS:iteration()
   return m.min(self.niter, self.history)
end

-- Correct the step-size (change of optimization variable)
-- by asserting that the norm of each vector is below
-- a given threshold.
function LBFGS:correct_dF(dF)

   -- Calculate the maximum norm
   local max_norm = self.norm1D(dF):max()

   -- Now normalize the displacement
   local norm = self.max_dF / max_norm
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
function LBFGS:add_history(F, G)

   -- Retrieve the current iteration step.
   -- With respect to the history and total
   -- iteration count.
   local iter = self:iteration()

   -- If the current iteration count is
   -- more than or equal to one, it means that
   -- we already have F0 and G0
   if iter > 0 then

      self.dF[iter] = F - self.F0
      self.dG[iter] = G - self.G0
      
      -- Calculate dot-product and store the kernel
      self.rho[iter] = 1. / self.flatdot(self.dF[iter] ,self.dG[iter])
      
   end
   
   -- In case we have stored too many points
   -- we should clean-up the history
   if iter > self.history then

      -- Forcing garbage collection
      table.remove(self.dF, 1)
      table.remove(self.dG, 1)
      table.remove(self.rho, 1)
	 
   end

   -- Ensure that the next iteration has
   -- the input sequence
   self.F0 = F:copy()
   self.G0 = G:copy()

end

-- Calculate the optimized variable (F) which
-- minimizes the gradient (G).
function LBFGS:optimize(F, G)
   
   -- Add the current iteration to the history
   self:add_history(F, G)

   -- Retrieve current iteration count
   local iter = self:iteration()

   -- Create local pointers to tables
   -- (they are tables, hence by-reference)
   local dF = self.dF
   local dG = self.dG
   local rho = self.rho

   -- Create table for accumulating dot products
   local rh = {}
   
   -- Update the uphill gradient
   local q = G:reshape(-1)
   for i = iter, 1, -1 do
      rh[i] = rho[i] * dF[i]:reshape(-1):dot(q)
      q = q - rh[i] * dG[i]:reshape(-1)
   end

   -- Solve for the rhs optimization
   local z = q * self.H0
   -- Clean-up
   q = nil

   -- Now create the next step
   for i = 1, iter do
      local beta = rho[i] * dG[i]:reshape(-1):dot(z)
      z = z + dF[i]:reshape(-1) * (rh[i] - beta)
   end
   
   -- Ensure shape
   z = - z:reshape(G.shape)
   
   -- Update step
   self.rho_optimized = m.abs(self.flatdot(G, z))
   local delta = self:correct_dF(z) * self.damping
   
   -- Determine whether we have optimized the parameter/functional
   self:optimized(G)

   -- Calculate next step
   local newF
   if not self.is_optimized then
      newF = F + delta
   else
      newF = F:copy()
   end

   self.niter = self.niter + 1
   
   return newF
      
end

-- Function to determine whether the
-- LBFGS algorithm has converged
function LBFGS:optimized(G)
   -- Check convergence
   local norm = self.norm1D(G):max()

   -- Determine whether the algorithm is complete.
   self.is_optimized = norm < self.tolerance
   
end

-- Print information regarding the LBFGS algorithm
function LBFGS:info()

   print("")
   if self:iteration() == 0 then
      print("LBGFS: history: " .. self.history)
   else
      print("LBGFS: current / history: "..tostring(self:iteration()) .. " / "..self.history)
   end
   print("LBGFS: damping "..tostring(self.damping))
   print("LBGFS: H0 "..tostring(self.H0))
   print("LBGFS: Tolerance "..tostring(self.tolerance))
   print("LBGFS: Maximum change "..tostring(self.max_dF))
   print("")

end

return LBFGS
