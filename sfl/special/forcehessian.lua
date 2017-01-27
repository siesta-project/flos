--[[ 
This module implements the force-constants routine
for doing an FC run with optimized displacements
according to the maximum displacement.
--]]

local m = require "math"
local mc = require "sfl.middleclass.middleclass"
local optim = require "sfl.optima.base"

-- Class for performing force-constant runs
local ForceHessian = mc.class('ForceHessian')

function ForceHessian:initialize(xa, indices, displacement, amass)

   -- Performing an FC run requires
   -- a few things
   -- 1. the initial atomic coordinates (from where the initial force constants are runned)
   -- 2. the indices of the atoms that should be displaced
   -- 3. the maximum displacement (defaults to 0.02 Ang)
   -- 4. the mass of the atoms (to scale the displacements)
   --    If not supplied they will all be the same

   -- We copy them because we need to be sure that they
   -- work
   self.xa = xa:copy()
   self.indices = indices
   self.displ = displacement

   -- Optional argument
   if amass then
      self.mass = amass
   else
      -- Create fake mass with all same masses
      -- No need to duplicate data, we simply
      -- create a metatable (deferred lookup table with
      -- the same return value).
      self.mass = setmetatable({__len =
				   function ()
				      return #self.xa
				   end
			       },
			       { __index = 
				    function(t,k)
				       return 1.
				    end
			       })
   end

   -- Calculate the maximum mass
   self.mass_max = 0.
   for i = 1, #self.mass do
      self.mass_max = m.max(self.mass_max, self.mass[i])
   end

   -- Local variables for tracking the FC run
   self.itt = 0
   self.dir = 1

   -- Create variable for 0 forces
   self.F0 = nil
   
   -- Create table for the forces of the other atoms
   self.F = {}
   for i = 1, #self.indices do
      local ia = self.indices[i]
      self.F[ia] = {}
   end

end

-- Whether or not the FC displacement is complete
function ForceHessian:done()
   return self.itt > #self.indices
end

-- Calculate the displacement of atom ia
function ForceHessian:displacement( ia )
   return m.sqrt(self.mass[ia] / self.mass_max) * self.displ
end

-- Retrieve the next coordinates for the FC run
function ForceHessian:next(fa)

   -- Get copy of the xa0 coordinates
   local xa = self.xa:copy()
   local ia
   local dx
   
   -- The first step
   if self.itt == 0 then
      self.itt = 1
      self.dir = 1

      -- Store the initial forces
      if fa ~= nil then
	 self.F0 = fa:copy()
      end

   elseif fa ~= nil then
      
      -- Store the forces from the previous
      -- displacement
      ia = self.indices[ self.itt ]
      self.F[ia][self.dir] = fa - self.F0
      
   end
   
   -- In case the last move was the last displacement of
   -- the previous atom
   if self.dir == 6 then
      self.dir = 1
      self.itt = self.itt + 1
   end

   -- In case we have just stepped outside of the
   -- displacement atoms
   if self:done() then
      return xa
   end

   -- Calculate the displacement according to
   -- the atomic mass and the max-displacement
   ia = self.indices[ self.itt ]
   dx = self:displacement( ia )
   
   if     self.dir == 1 then
      xa[ia][1] = xa[ia][1] + dx
   elseif self.dir == 2 then
      xa[ia][1] = xa[ia][1] - dx
   elseif self.dir == 3 then
      xa[ia][2] = xa[ia][2] + dx
   elseif self.dir == 4 then
      xa[ia][2] = xa[ia][2] - dx
   elseif self.dir == 5 then
      xa[ia][3] = xa[ia][3] + dx
   elseif self.dir == 6 then
      xa[ia][3] = xa[ia][3] - dx
   end

   return xa
   
end

return ForceHessian
