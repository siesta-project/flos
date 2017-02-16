---
-- Implementation of the limited memory BFGS algorithm
-- @classmod LBFGS

local m = require "math"
local mc = require "flos.middleclass.middleclass"

local optim = require "flos.optima.base"

-- Create the LBFGS class (inheriting the Optimizer construct)
local LBFGS = mc.class("LBFGS", optim.Optimizer)


--- Instantiating a new `LBFGS` object.
--
-- The LBFGS algorithm is a straight-forward optimization algorithm which requires
-- very few arguments for a succesful optimization.
-- The most important parameter is the initial Hessian value, which for large values (close to 1)
-- may have difficulties in converging because it is more aggressive (keeps more of the initial
-- gradient). The default value is rather safe and should enable optimization on most systems.
--
-- @usage
-- lbfgs = LBFGS:new({<field1 = value>, <field2 = value>})
-- while not lbfgs:optimized() do
--    F = lbfgs:optimize(F, G)
-- end
--
-- @function LBFGS:new
-- @number[opt=1] damping damping parameter for the parameter change
-- @number[opt=1/75] H0 initial Hessian value, larger values are more safe, but takes possibly longer to converge
-- @int[opt=25] history number of previous steps used when calculating the new Hessian
-- @param ... any arguments `Optimizer:new` accepts
local function doc_function()
end

function LBFGS:initialize(tbl)
   -- Initialize from generic optimizer
   optim.Optimizer.initialize(self)

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
   self.H0 = 1. / 75.

   -- Number of previous history points used
   self.history = 25

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
   self.weight = 1.

   -- Ensure we update the elements as passed
   -- by new(...)
   if type(tbl) == "table" then
      for k, v in pairs(tbl) do
	 self[k] = v
      end
   end

end

--- Reset the `LBFGS` object
function LBFGS:reset()
   optim.Optimizer.reset(self)
   self.F0 = {}
   self.G0 = {}
   self.dF = {}
   self.dG = {}
   self.rho = {}
   self.weight = 1.
end



--- Normalize the parameter displacement to a given max-change.
-- The LBFGS algorithm always perfoms a global correction to maintain
-- the minimization direction.
-- @Array dF the parameter displacements that are to be normalized
-- @return the normalized `dF` according to the `global` or `local` correction
function LBFGS:correct_dF(dF)

   -- Calculate the maximum norm
   local max_norm
   if #dF.shape == 1 then
      max_norm = dF:abs():max()
   else
      max_norm = dF:norm():max()
   end

   -- Now normalize the displacement
   local norm = self.max_dF / max_norm
   if norm < 1. then
      return dF * norm
   else
      return dF
   end
   
end

--- Add the current optimization variable and the gradient variable to the history.
-- This function calculates the residuals and updates the kernel of the residual dot-product.
-- @Array F the parameters for the function
-- @Array G the gradient of the function with the parameters `F`
function LBFGS:add_history(F, G)

   -- Retrieve the current iteration step.
   -- With respect to the history and total
   -- iteration count.
   local iter = m.min(self:iteration(), self.history)

   -- If the current iteration count is
   -- more than or equal to one, it means that
   -- we already have F0 and G0
   if iter > 0 then

      self.dF[iter] = F - self.F0
      self.dG[iter] = G - self.G0
      
      -- Calculate dot-product and store the kernel
      self.rho[iter] = -1. / self.dF[iter]:flatdot(self.dG[iter])
      if self.rho[iter] == -m.huge or m.huge == self.rho[iter] then
	 -- An inf number 
	 self.rho[iter] = 0.
      elseif self.rho[iter] ~= self.rho[iter] then
	 -- A nan number does not equal it-self
	 self.rho[iter] = 0.
      end

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



--- Perform a LBFGS step with input parameters `F` and gradient `G`
-- @Array F the parameters for the function
-- @Array G the gradient for the function with parameters `F`
-- @return a new set of parameters which should converge towards a
--   local minimum point.
function LBFGS:optimize(F, G)
   
   -- Add the current iteration to the history
   self:add_history(F, G)

   -- Retrieve current iteration count
   local iter = m.min(self:iteration(), self.history)

   -- Create local pointers to tables
   -- (they are tables, hence by-reference)
   local dF = self.dF
   local dG = self.dG
   local rho = self.rho

   -- Create table for accumulating dot products
   local rh = {}
   
   -- Update the downhill gradient
   local q = - G:flatten()
   for i = iter, 1, -1 do
      rh[i] = rho[i] * dF[i]:flatdot(q)
      q = q + rh[i] * dG[i]:flatten()
   end

   -- Solve for the rhs optimization
   local z = q * self.H0
   -- Clean-up
   q = nil

   -- Now create the next step
   for i = 1, iter do
      local beta = rho[i] * dG[i]:flatdot(z)
      z = z + dF[i]:flatten() * (rh[i] + beta)
   end
   
   -- Ensure shape
   z = - z:reshape(G.shape)
   
   -- Update step
   self.weight = m.abs(G:flatdot(z))
   local dF = self:correct_dF(z) * self.damping
   
   -- Determine whether we have optimized the parameter/functional
   self:optimized(G)
   
   self.niter = self.niter + 1

   -- return optimized coordinates, regardless
   return F + dF
      
end


--- Print information regarding the `LBFGS` object
function LBFGS:info()

   print("")
   local it = m.min(self:iteration(), self.history)
   if it == 0 then
      print("LBFGS: history: " .. self.history)
   else
      print("LBFGS: current / history: "..tostring(it) .. " / "..self.history)
   end
   print("LBFGS: damping "..tostring(self.damping))
   print("LBFGS: H0 "..tostring(self.H0))
   print("LBFGS: Tolerance "..tostring(self.tolerance))
   print("LBFGS: Maximum change "..tostring(self.max_dF))
   print("")

end

return LBFGS
