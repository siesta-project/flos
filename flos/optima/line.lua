--[[ 
This module implements a simple line search method which
may be subclassed and improved.
--]]

local m = require "math"
local mc = require "flos.middleclass.middleclass"

local optim = require "flos.optima.base"
local LBFGS = require "flos.optima.lbfgs"

-- Create the line search class (inheriting the Optimizer construct)
local Line = mc.class("Line", optim.Optimizer)

function Line:initialize(tbl)

   -- this is the convergence tolerance of the gradient
   self.tolerance = 0.02
   self.is_optimized = false
   
   -- Maximum change in functional allowed (cut-off)
   self.max_dF = 0.1

   -- The initial direction of the line-search
   self.direction = nil

   -- The alpha that minimizes the direction
   self.alpha = 1.

   -- Initialize method to check
   self.optimizer = nil

   -- Ensure we update the elements as passed
   -- by new(...)
   if type(tbl) == "table" then
      for k, v in pairs(tbl) do
	 self[k] = v
      end
   end
   
   if self.optimizer == nil then
      -- The optimization method
      self.optimizer = LBFGS(
	 { tolerance = self.tolerance,
	   max_dF = self.max_dF,
	 })
   end

end

-- Reset the algorithm
-- Basically all variables that
-- are set should be reset
function Line:reset()
   self.direction = nil
   self.initial = nil
   self.alpha = 1.
   self.optimizer:reset()
end


-- Return the projected gradient along the line-search
function Line:projection(G)
   
   -- Project onto the direction
   local dnorm2 = self.direction:norm(0) ^ 2
   -- a . b / |b|^2 b
   local proj = G:flatten():dot( self.direction:flatten() ) / dnorm2 * self.direction

   return proj
end

-- Special optimized routine for a line-search
function Line:optimized(G)
   
   -- determine if the projected gradient has been optimized
   return optim.Optimizer.optimized(self, self:projection(G))

end

-- Calculate the optimized variable (F) which
-- minimizes the gradient (G).
function Line:optimize(F, G)

   -- Create initial direction
   if self.direction == nil then
      self.initial = F:copy()
      self.direction = G:copy()
      -- Reset alpha to zero
      self.alpha = 0.
   end

   -- Calculate the new variables given the constraint on the projected vector
   local new = self.optimizer:optimize(F, self:projection(G))
   
   -- Before we return the new coordinates we need to update the alpha parameter
   self.alpha = (new - self.initial):flatten():dot( self.direction:flatten() ) /
      self.direction:norm(0)
   
   return new

end


-- Print information regarding the Line algorithm
function Line:info()
   
   print("")
   print("Line: line search:")
   self.optimizer:info()
   print("")

end

return Line
