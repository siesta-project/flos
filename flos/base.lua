
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
	 floserr('Total size of the array specification is not maintained.')
      end
   elseif istable(bound[1]) then
      -- immediately convert to simple table (instead of nested)
      bound = bound[1]
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
      floserr('Only 1 index may be automatically identified.')
   elseif nm == 1 then
      -- The user has requested one adaptable index
      nm = m.floor(size / bs)
      if bs * nm ~= size then
	 floserr('Total size of new array must be unchanged.')
      end

      -- Now create the correct size
      for i = 1, nbound do
	 if ret[i] == -1 then
	    ret[i] = nm
	 end
      end
   elseif bs ~= size then
      floserr('Total size of new array must be unchanged.')
   end

   -- Return new size of the array
   return ret
end

-- Function to return if an object is a table
local floserr = function(msg)
   -- Print out a stack-trace without this function call
   print(debug.traceback(nil, 2))
   error(msg)
end

return {
   -- Generic utility functions
   ['floserr'] = floserr,
   ['arrayBounds'] = arrayBounds,
   -- Class-determination methods
   ['istable'] = istable,
   ['instanceOf'] = instanceOf,
   ['subclassOf'] = subclassOf,
   -- Classes
   ['Array'] = Array,
   ['Array1D'] = Array1D,
   ['Array2D'] = Array2D,
}
