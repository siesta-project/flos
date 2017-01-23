
--[[ 
Create a table with the default parameters of 
the Optima functions that are going to be inherited.
--]]

require "math"
local A = require "array"

function istable(t)
   return type(t) == 'table'
end

LBFGS = {
   
   -- Damping of the BFGS algorithm
   --  > 1: over-relaxed
   --  < 1: under-relaxed
   damp = 1.2,
   
   -- Initial inverse Hessian
   -- Lower values converges faster at the risk of
   -- instabilities
   -- Larger values are easier to converge
   invH = 50.,

   -- Number of history points used
   history = 100,

   -- Converged difference of the constraint
   conv_C = 0.02, 
   is_relaxed = false,

   -- Maximum change in functional allowed (cut-off)
   max_dP = 0.1,
   
   -- This is the field of the functional we
   -- wish to optimize with regards to the minimization
   -- values C
   P0 = {},
   -- This is the field of the constraints we
   -- wish to minimize.
   C0 = {},

   -- The history of dP, dC and 1. / ( dP.dC )
   dP = {},
   dC = {},
   rho = {},

   -- The current itteration
   nitt = 0,

   -- Function to return the current itteration
   -- count
   itt = function (self)
      return math.min(self.nitt, self.history)
   end,

   -- Correct the functional change by normalization
   -- to a maximum value
   correct_dP = function (self, dP)
      -- Calculate the maximum norm
      local norm = dP:norm()
      local n1 = #dP
      local n = 0.
      for i = 1, #norm do
	 n = math.max(n, norm[i])
      end

      -- Now normalize dP
      n = self.max_dP / n
      if n < 1. then
	 return dP * n
      else
	 return dP
      end
      
   end,

   -- Update history with elements
   add_history = function(self, P, C)

      -- Get current itteration
      local itt = self:itt()
      -- Full size
      local n = P.size[1] * P.size[2]
      if itt > 0 then

	 -- Now we may add to the history
	 self.dP[itt] = P - self.P0
	 self.dC[itt] = C - self.C0

	 -- Calculate dot-product and store it
	 self.rho[itt] = 1. / self.dP[itt]:reshape(n):dot(self.dC[itt]:reshape(n))
      end

      -- In case we have stored too many points
      -- we should clean-up the history
      if itt > self.history then

	 -- Forcing garbage collection
	 table.remove(self.dP, 1)
	 table.remove(self.dC, 1)
	 table.remove(self.rho, 1)
	 
      end

      -- Update the values
      self.P0 = P:copy()
      self.C0 = C:copy()

   end,

   -- LBFGS algorithm for taking a step
   next = function(self, P, C)

      -- Add the current iteration to the history
      self:add_history(P, C)

      -- Retrieve current itteration count
      local itt = self:itt()
      -- Size of the array
      local n = P.size[1] * P.size[2]

      -- Create local pointers to tables
      local dP = self.dP
      local dC = self.dC
      local rho = self.rho

      -- Create table for accumulating dot products
      local rh = {}

      -- Create a copy of the constraint
      local q = - C:reshape(n)
      for i = itt, 1, -1 do
	 rh[i] = rho[i] * q:dot(dP[i]:reshape(n))
	 -- Note dC is C - C0
	 q = q - rh[i] * dC[i]:reshape(n)
      end
      local z = q / self.invH
      q = nil

      -- Now create the next step
      for i = 1, itt do
	 -- Note dC is C - C0
	 local tmp = rho[i] * dC[i]:reshape(n):dot(z)
	 z = z - dP[i]:reshape(n) * (rh[i] + tmp)
      end

      -- Ensure shape
      local p = - z:reshape(C.size)

      -- Update step
      local dp = self:correct_dP(p) * self.damp

      -- Update relaxation
      self:relaxed(C)

      -- Calculate next step
      local newP
      if not self.is_relaxed then
	 newP = P + dp
      else
	 newP = P:copy()
      end

      self.nitt = self.nitt + 1
      
      return newP
      
   end,

   -- Function to determine whether the
   -- LBFGS algorithm has converged
   relaxed = function(self, C)
      -- Check convergence
      local c = C:norm()
      self.is_relaxed = true
      for i = 1, #c do
	 if c[i] > self.conv_C then
	    self.is_relaxed = false
	 end
      end
   end,

   -- Print information regarding the LBFGS algorithm
   info = function(self)

      if self.nitt == 0 then
	 print("Welcome to LBFGS algorithm...")
      end

      print("LBGFS.itt "..tostring(self.nitt))
      print("LBGFS.history "..tostring(self.history))
      print("LBGFS.damping "..tostring(self.damp))
      print("LBGFS.H0 "..tostring(1. / self.invH))
      
   end,
}

return LBFGS
