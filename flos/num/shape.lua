--[[
A shape is a simple array with integers >= 0 such that they
describe a shape of an array.

Importantly one can define any _one_ of the array values by 
0/nil to notify a variable length dimension for alignment with 
another 

Their basic use, if not only, is to describe the shape of any
Array (see num/array.lua).

Their main purpose is to assert that 
--]]
local m = require "math"
local mc = require "flos.middleclass.middleclass"

local ferr = require "flos.error"
local error = ferr.floserr

-- Create the shape class (globally so it returns)
local Shape = mc.class("Shape")

local function isShape(obj)
   if type(obj) == "table" then
      if obj.class then
	 return obj:isInstanceOf(Shape)
      end
   end
   return false
end

-- Function for returning the axis as provided by transfering nil to 0
local function ax_(axis)
   if axis == nil then
      return 0
   else
      return axis
   end
end


-- The initialization method accepts any number of arguments
-- which defines a new shape.
function Shape:initialize(...)
   local args = {...}

   if #args == 0 then
      error("flos.Shape must have at least one dimension")
   end

   local zero = false
   for i, v in ipairs(args) do
      rawset(self, i, v)
      if v == 0 then
	 if zero then
	    error("flos.Shape must not be initialized with more than one 0 value.")
	 end
	 zero = true
      end
   end

end

-- Return a copy of this shape
function Shape:copy()
   return Shape( table.unpack(self) )
end

-- Return a reverse shape
function Shape:reverse()
   -- create the reversed shape
   local sh = {}
   for i = #self, 1, -1 do
      sh[#sh+1] = m.tointeger(self[i])
   end
   -- This is the new shape
   return Shape( table.unpack(sh) )
end

-- Return the size along a given dimension,
-- equivalent to Shape[1], for Shape:size(1), however,
-- if 0 is passed it returns the full size.
function Shape:size(axis)
   local ax = ax_(axis)
   local size = 1
   if ax == 0 then
      -- We return the full size
      for _, v in ipairs(self) do
	 if v ~= 0 then
	    size = size * v
	 end
      end
   else
      size = self[ax]
   end
   return m.tointeger(size)
end

-- Return a new shape _without_ the given dimension
function Shape:remove(axis)
   local ax = ax_(axis)
   if ax == 0 then
      error("flos.Shape removing an axis requires a specific axis")
   end
   local s = {}
   for i, v in ipairs(self) do
      if i ~= ax then
	 s[#s+1] = v
      end
   end
   if #s == 0 then
      return nil
   end
   return Shape( table.unpack(s) )
end

-- Return true/false whether the shape has an unknown dimension
function Shape:zero()
   for i, v in ipairs(self) do
      if v == 0 then
	 return i
      end
   end
   return 0
end


-- Returns a new shape with an aligned shape according to other.
-- If other is nil, a copy of self.shape will be returned
-- if other is a shape with a single 0, the unknown dimensions size will be
-- calculated and a new shape will be returned. In case the size does not
-- match, a nil will be returned (to signal no alignment)
function Shape:align(other)
   if other == nil then
      return self:copy()
   end

   local zero_s = self:zero()
   local zero_o = other:zero()
   local size_s = self:size()
   local size_o = other:size()

   -- Now check that they are the same
   if zero_s ~= 0 and zero_o ~= 0 then
      return nil
      
   elseif zero_s ~= 0 then
      -- we align ->, not to the left
      return nil
      
   elseif zero_o ~= 0 then

      local n = size_s / size_o
      if n * size_o ~= size_s then
	 return nil
      end

      local new = other:copy()
      new[zero_o] = m.tointeger(n)
      return new

   elseif self:size() ~= other:size() then

      -- The shapes are not the same...
      return nil

   else

      -- The shape is copied because they are the same
      return other:copy()

   end
end

-- Convert the Shape to a pretty-printed string
function Shape:__tostring()
   local s = "[" .. tostring(self[1])
   for i = 2 , #self do
      s = s .. ', ' .. tostring(self[i])
   end
   return s .. ']'
end
   

-- Determine whether two shapes are the same
function Shape.__eq(a, b)
   if #a ~= #b then
      return false
   end
   
   for i, v in ipairs(a) do
      if v ~= b[i] then
	 return false
      end
   end
   
   return true
end


-- The return table for this module
return {
   ["Shape"] = Shape,
   ["isShape"] = isShape,
}
