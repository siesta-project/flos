-- Array1D library
-- Implementing simple Array1D classes

local _m  = require "math"

local cls = require "flos.base"
local Array1D = cls.Array1D
local Array2D = cls.Array2D

local istable = cls.istable

-- Create the stride selection 
-- Array1D[i..":"..j..":"..step]

function Array1D.__newindex(self, k, v)
   if string.lower(tostring(k)) == "all" then
      if istable(v) then
	 error("ERROR  Assigning all elements in a vector to a table"
		  .." is not allowed. They are assigned by reference.", 2)
      end
      for i = 1 , #self do
	 self[i] = v
      end
   else
      if k < 1 or self.shape[1] < k then
	 error("ERROR  index is out of bounds", 2)
      end
      rawset(self, k, v)
   end
end

function Array1D:initialize(...)
   -- Convert input option to a correct shape
   local shape = {...}
   
   -- Check wheter the table is a table of shape
   if #shape == 1 then
      if cls.istable(shape[1]) then
	 shape = shape[1]
      end
   end

   if #shape ~= 1 then
      error("ERROR  shape initialization for Array1D is incompatible", 2)
   end
   -- Check sizes
   if shape[1] < 1 then
      error("ERROR  You are initializing a vector with size <= 0.", 2)
   end
   -- Rawset is needed to not call the bounds-check
   rawset(self, "shape", shape)
   rawset(self, "size", self.shape[1])
end

-- Create an empty 1D array
function Array1D.empty(shape)
   return Array1D:new(shape)
end

-- Return a 1D array with initialized 0's
function Array1D.zeros(shape)
   local new = Array1D.empty(shape)
   for i = 1, #new do
      new[i] = 0.
   end
   return new
end

-- Return a 1D array with only 1.'s
function Array1D.ones(shape)
   local new = Array1D.empty(shape)
   for i = 1, #new do
      new[i] = 1.
   end
   return new
end

-- Read a 1D array from a table.
-- In case the table has two dimensions
-- a 2D array will automatically be returned
function Array1D.from(tbl)
   local new
   if istable(tbl[1]) then
      new = Array2D.empty(#tbl, #tbl[1])
      for i = 1, #tbl do
	 for j = 1, #tbl[i] do
	    new[i][j] = tbl[i][j]
	 end
      end
      new = new:reshape(-1)
   else
      local n = #tbl
      new = Array1D.empty(n)
      for i = 1, #tbl do
	 new[i] = tbl[i]
      end
   end
   return new
end


-- Create a 1D array with a range
--   for i = i1, i2, step
function Array1D.range(i1, i2, step)
   local is = step or 1
   if is == 0 then
      error("Array1D.range with zero step-length creates an infinite table.")
   elseif is > 0 and i1 > i2 then
      error("Array1D.range with positive step-length and i1 > i2 is not allowed.")
   elseif is < 0 and i1 < i2 then
      error("Array1D.range with negative step-length and i1 < i2 is not allowed.")
   end

   local new = Array1D.empty(1)
   local j = 0
   for i = i1, i2, is do
      j = j + 1
      if i ~= i1 then
	 -- because we cannot initialize an array to size 0
	 new:extend(1)
      end
      new[j] = i
   end

   return new
end

-- Extend the size of the Array
function Array1D:extend(n)
   local ln = n or 1
   local ns = self.size + ln
   rawset(self, "shape", {ns})
   rawset(self, "size", ns)
end

-- Copy (data copy)
function Array1D:copy()
   local new = Array1D.empty(#self)
   for i = 1, #self do
      new[i] = self[i]
   end
   return new
end

-- Create a new array which holds the differences
-- for each consecutive element, has size #self-1
function Array1D:diff()
   local new = Array1D.empty(#self-1)
   for i = 1, #new do
      new[i] = self[i+1] - self[i]
   end
   return new
end


-- Return the absolute value of all elements
function Array1D:abs()
   local new = Array1D.empty(#self)
   for i = 1, #new do
      new[i] = _m.abs(self[i])
   end
   return new
end


function Array1D:reshape(...)
   -- Grab variable arguments
   local new_size = cls.arrayBounds(self.size, {...})
   local nsize = #new_size

   if nsize == 0 or nsize == 1 then

      -- Simply return a copy, size is the same.
      new = self:copy()

   elseif nsize == 2 then
      
      new = Array2D.empty(new_size)
      
      -- initialize loop conters
      local k, l = 1, 0
      for i = 1, #self do
	 l = l + 1
	 if l > new.shape[2] then
	    l = 1
	    k = k + 1
	 end
	 new[k][l] = self[i]
      end
      
   else
      error("Array1D: reshaping not implemented", 2)
      
   end

   return new
end

-- This "fake" table ensures that single values are indexable
-- I.e. we create an index function which returns the same value for any given
-- value.
local function ensuretable(val)
   if istable(val) then
      return val
   else
      -- We must have a number, fake the table
      -- In this case the table returns the same value
      -- for all indices
      -- Easy way to not duplicate code for handling
      -- values.
      return setmetatable({size = 1, class = false},
			  { __index = 
			       function(t,k)
				  return val
			       end
			  })
   end
end

local function opt_get(lhs, rhs)
   -- an option parser for the functions that need the 
   -- correct information
   local t = {}
   local s = 0
   local ls , rs = 0 , 0
   if cls.instanceOf(lhs, Array1D) then
      ls = lhs.size or 0
   else
      ls = 1
   end
   t.lhz = ensuretable(lhs)
   if cls.instanceOf(rhs, Array1D) then
      rs = rhs.size or 0
   else
      rs = 1
   end
   t.rhz = ensuretable(rhs)
   if ls ~= rs then
      if ls ~= 1 and rs ~= 1 then
	 error("ERROR  Array1D dimensions incompatible")
      end
   end
   t.size = _m.max(ls, rs)
   return t
end


-- Create the iterators (pairs and ipairs are the same)
-- /for i,v in pairs(Array1D) do\
function Array1D.__ipairs(self)
   -- multiple assignment simultaneously
   local i , n = 0 , #self
   return function()
      i = i + 1
      if i <= n then
	 return i, self[i]
      end
   end
end

-- /for i,v in pairs(Array1D) do\
function Array1D.__pairs(self)
   return ipairs(self)
end

-- Length lookup
-- /for i = 1 , #Array1D do\
function Array1D.__len(self)
   return self.size
end


-- Implementation of norm function
function Array1D:norm()
   local n = 0.
   for i = 1 , #self do
      n = n + self[i] * self[i]
   end
   return _m.sqrt(n)
end

-- Implementation of the dot product
function Array1D.dot(lhs, rhs)
   if cls.instanceOf(rhs, Array2D) then
      return rhs.dot(lhs, rhs)
   end
   local t = opt_get(lhs, rhs)
   local v = 0.
   -- We have now created the corrrect new vector for containing the
   -- data
   -- Loop over the vector size
   for i = 1 , t.lhz.size do
      v = v + t.lhz[i] * t.rhz[i]
   end
   return v
end

-- Implementation of the cross product
function Array1D.cross(lhs, rhs)
   if not cls.instanceOf(lhs, Array1D) or
   not cls.instanceOf(rhs, Array1D) then
      error("Array1D: cross-product requires two 1D arrays")
   end
   if #lhs ~= 3 then
      error("Array1D: cross-products are only defined in 3D space")
   end

   local v = Array1D.empty(#lhs)
   v[1] = lhs[2] * rhs[3] - lhs[3] * rhs[2]
   v[2] = lhs[3] * rhs[1] - lhs[1] * rhs[3]
   v[3] = lhs[1] * rhs[2] - lhs[2] * rhs[1]
   return v
end

--[[
   We need to create all the different methods for 
   numerical stuff
--]]
function Array1D.__add(lhs, rhs)
   local t = opt_get(lhs, rhs)
   -- Create the new vector
   local v = Array1D.empty(t.size)
   
   -- We have now created the corrrect new vector for containing the
   -- data
   -- Loop over the vector size
   for i = 1 , #v do
      v[i] = t.lhz[i] + t.rhz[i]
   end
   return v
end

function Array1D.__sub(lhs, rhs)
   local t = opt_get(lhs, rhs)
   -- Create the new vector
   local v = Array1D.empty(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] - t.rhz[i]
   end
   return v
end

function Array1D.__mul(lhs, rhs)
   local t = opt_get(lhs, rhs)
   -- Create the new vector
   local v = Array1D.empty(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] * t.rhz[i]
   end
   return v
end

function Array1D.__div(lhs, rhs)
   local t = opt_get(lhs, rhs)
   -- Create the new vector
   local v = Array1D.empty(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] / t.rhz[i]
   end
   return v
end

function Array1D.__pow(lhs, rhs)
   local t = opt_get(lhs, rhs)
   -- Create the new vector
   local v = Array1D.empty(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] ^ t.rhz[i]
   end
   return v
end

-- Unary minus operation
function Array1D:__unm()
   local v = Array1D.empty(self.size)
   for i = 1 , #v do
      v[i] = -self[i]
   end
   return v
end

-- Convert the content of the array to a string
function Array1D.__tostring(self)
   local s = "[" .. tostring(self[1])
   for i = 2 , #self do
      s = s .. ', ' .. tostring(self[i])
   end
   return s .. ']'
end

return Array1D
