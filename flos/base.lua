
-- Definitions local classes used in this project
local m = require "math"

local mc = require "flos.middleclass.middleclass"

local Array = mc.class('Array')
local Array1D = mc.class("Array1D", Array)
local Array2D = mc.class("Array2D", Array)

-- Function to return if an object is a table
local istable = function (obj)
   return type(obj) == "table"
end

-- Function to return if an object is an instance of
-- a certain class.
-- Wraps checks for the middleclass functions
local instanceOf = function (obj, class)
   if istable(obj) then
      if obj.class then
	 return obj:isInstanceOf(class)
      end
   end
   return false
end

-- Function to return if an object is a subclass of
-- a certain class.
-- Wraps checks for the middleclass functions
local subclassOf = function (obj, class)
   if istable(obj) then
      if obj.class then
	 return obj:isSubclassOf(class)
      end
   end
   return false
end

-- Given the total size of an array this function
-- returns updated bounds such that the bounds
-- fulfils the total size.
local arrayBounds = function (size, bound)
   -- Quickly figure out if this is a table,
   -- or whether the size is completed.
   if bound == nil then
      return {size}
   elseif not istable(bound) then
      if bound < 0 then
	 -- return the actual size
	 return {size}
      elseif bound ~= size then
	 -- Print out an error message with stack-trace to see the resulting code
	 -- which subjected the error
	 error('Total size of the array specification is not maintained.', 2)
      end
   end

   -- Now we can do the analysis based on the table size
   local nbound = #bound
   -- Quick return if there are no arguments
   if nbound == 0 then
      return {size}
   end
   local ret = {}

   -- The sizes as calculated via the bound table
   local bs = 1
   local nm = 0
   for i = 1, nbound do
      if bound[i] > 0 then
	 ret[i] = bound[i]
	 bs = bs * bound[i]
      else
	 -- set to minus one
	 ret[i] = -1
	 -- update number of negatives
	 nm = nm + 1
      end
   end
   if nm > 1 then
      -- Quick escape if wrong options
      error('Only 1 index may be automatically identified.', 2)
   elseif nm == 1 then
      -- The user has requested one adaptable index
      nm = m.floor(size / bs)
      if bs * nm ~= size then
	 error('Total size of new array must be unchanged.', 2)
      end

      -- Now create the correct size
      for i = 1, nbound do
	 if ret[i] == -1 then
	    ret[i] = nm
	 end
      end
   elseif bs ~= size then
      error('Total size of new array must be unchanged.', 2)
   end

   -- Return new size of the array
   return ret
end

return {
   -- Class-determination methods
   ['istable'] = istable,
   ['instanceOf'] = instanceOf,
   ['subclassOf'] = subclassOf,
   ['arrayBounds'] = arrayBounds,
   -- Classes
   ['Array'] = Array,
   ['Array1D'] = Array1D,
   ['Array2D'] = Array2D,
}
