--[[ 
A simple class to retain an MD step. Hence the name MDStep.

Such an MDStep contains several parameters:
-- R, the atomic coordinates
-- V, the velocities
-- F, the forces
-- E, the total energy associated with the configuration

Ideally the above parameters need not be contained. And one may
additionally add other quantities by an external table.
--]]

local mc = require "flos.middleclass.middleclass"

local MDStep = mc.class("MDStep")

function MDStep:initialize(args)

   -- Initialize an MDStep class with the appropriate table quantities

   -- Ensure we update the elements as passed
   -- by new(...)
   if type(args) == "table" then
      for k, v in pairs(args) do
	 self[k] = v
      end
   end
   
end

-- Easy set function for setting any value in the MDstep
-- This routine may NOT be used by passing a table of content
-- to be copied into the container.
function MDStep:set(args)

   -- Routine for setting specific settings through
   -- direct table additions, i.e.
   --   MDStep:set(R= R)
   -- will subsequently allow:
   --   MDStep.R
   -- queries.

   for k, v in pairs(args) do
      self[k] = v
   end
end


-- Create wrapper functions for setting a couple of the most used
-- quantities
function MDStep:set_R(R)
   self:set{R=R}
end
function MDStep:set_V(V)
   self:set{V=V}
end
function MDStep:set_F(F)
   self:set{F=F}
end
function MDStep:set_E(E)
   self:set{E=E}
end

-- Easy printing routine for show the content
function MDStep:print()

   for k, v in pairs(self) do
      print(k, v)
   end
end

return MDStep
