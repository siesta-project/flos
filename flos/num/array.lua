--[[
An Array library which implements basic Lua arrays with arbitrary
dimensions.

Because it is in native Lua many of the functions are creating
unneccessary duplications before doing operations. This is by
design to ease the implementation and as such it is not meant for
large scale numerical work.

The implementation is based on a nested table container of the 
underlying Array class. In effect an Array of dimension 3, is in reality
a table of Array with dimension 2, and each of these are Arrays of dimension
1.
--]]
local m = require "math"
local mc = require "flos.middleclass.middleclass"

local shape = require "flos.num.shape"

local Array = mc.class("Array")

local function isArray(obj)
   if type(obj) == "table" then
      if obj.class then
	 return obj:isInstanceOf(Array)
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
function Array:initialize(...)
   
   local sh = nil

   -- One may also initialize an Array by passing a
   -- shape class, so we need to check this
   local args = {...}
   if shape.isShape(args[1]) then
      sh = args[1]:copy()
   end
	    
   if sh == nil then
      sh = shape.Shape(...)
   end
   
   -- Create the shape container
   rawset(self, "shape", sh)

   -- For each size along the first dimension
   -- we create a new one for each of them
   if #self.shape > 1 then
      for i = 1, self.shape[1] do
	 rawset(self, i, Array( table.unpack(self.shape, 2) ))
      end
   end

end

function Array:__newindex(i, v)
   -- A new index *must* by definition be the last array
   -- in the shape
   if #self.shape ~= 1 then
      error("ERROR in implementation")
   end
   if i < 1 or self.shape[1] < i then
      error("ERROR setting element out of bounds")
   end
   rawset(self, i, v)
end

-- Wrapper for creating an array
function Array.empty(...)
   return Array(...)
end

-- Create a zero creation routine
function Array.zeros(...)
   -- Initialize the object
   local arr = Array(...)
   -- Fill all values with 0.
   arr:fill(0.)
   -- Return the array
   return arr
end

-- Create a one creation routine
function Array.ones(...)
   -- Initialize the object
   local arr = Array(...)
   -- Fill all values with 1.
   arr:fill(1.)
   -- Return the array
   return arr
end


-- Create a 1D array with a range
--   for i = i1, i2, step
function Array.range(i1, i2, step)
   -- Get the actual step (default 1)
   local is = step or 1
   if is == 0 then
      error("flos.Array range with zero step-length creates an infinite table.")
   elseif is > 0 and i1 > i2 then
      error("flos.Array range with positive step-length and i1 > i2 is not allowed.")
   elseif is < 0 and i1 < i2 then
      error("flos.Array range with negative step-length and i1 < i2 is not allowed.")
   end
   
   local new = Array.empty( m.ceil((i2-i1)/is) )
   local j = 0
   for i = i1, i2, is do
      j = j + 1
      new[j] = i
   end

   return new
end

-- Easy function for initialization and setting all
-- values in an Array to a single value. 
function Array:fill(val)
   if #self.shape == 1 then
      -- We are at the last dimension so we set
      -- the value accordingly
      for i = 1, self.shape[1] do
	 self[i] = val
      end
   else
      for i = 1, self.shape[1] do
	 self[i]:fill(val)
      end
   end
end

-- Create a copy of the Array
function Array:copy()
   local new = Array( self.shape:copy() )
   if #self.shape == 1 then
      -- We need to extract the values, rather than
      -- copying
      for i = 1, self.shape[1] do
	 new[i] = self[i]
      end
   else
      for i = 1, self.shape[1] do
	 new[i] = self[i]:copy()
      end
   end
   return new
end

-- Length lookup
-- /for i = 1 , #Array do\
function Array:__len()
   return self.shape[1]
end

-- Size query
function Array:size(axis)
   return self.shape:size(axis)
end

-- Query the data using a linear index
function Array:_get_index_lin(i)

   -- If we are at the last dimension, return immediately.
   if #self.shape == 1 then
      return self[i]
   end

   -- Calculate # of elements per first dimension
   local n_dim = self:size() / self:size(1)
   -- Calculate the first dimension index
   local j = m.tointeger( m.ceil(i / n_dim) )
   -- Transform i into the linear index in the underlying array
   return self[j]:_get_index_lin( m.tointeger(i - (j-1) * n_dim) )
end

-- Set the data using a linear index
function Array:_set_index_lin(i, v)

   -- If we are at the last dimension, return immediately.
   if #self.shape == 1 then
      self[i] = v
   else

      -- Calculate # of elements per first dimension
      local n_dim = self:size() / self:size(1)
      -- Calculate the first dimension index
      local j = m.tointeger( m.ceil(i / n_dim) )
      -- Transform i into the linear index in the underlying array
      self[j]:_set_index_lin( m.tointeger(i - (j-1) * n_dim), v)
      
   end
end


-- Reshaping an array
function Array:reshape(...)
   local arg = {...}
   if #arg == 0 then
      arg[1] = 0
   end

   -- Create a new shape
   local sh = self.shape:align( shape.Shape(table.unpack(arg)) )
   if sh == nil then
      error("flos.Array cannot align shapes, incompatible dimensions")
   end
   -- Create the new array
   local new = Array( sh )

   -- Loop on the linear indices
   for i = 1, self:size() do
      new:_set_index_lin(i, self:_get_index_lin(i))
   end

   return new
end


-- Create a copy of the array with the absolute values
function Array:abs()
   local a = Array( self.shape:copy() )

   -- Loop all values and create the absolute values
   if #self.shape == 1 then
      for i = 1, self.shape[1] do
	 a[i] = m.abs(self[i])
      end
   else
      for i = 1, self.shape[1] do
	 a[i] = self[i]:abs()
      end
   end
   return a
end

-- Extract the minimum of an array along a given dimension
function Array:min(axis)
   local ax = ax_(axis)

   -- Returned minimum
   local min

   -- Now figure out what to do
   if ax == 0 then

      -- We simply need to extract the total minimum
      if #self.shape == 1 then
	 min = self[1]
	 for i = 2, self.shape[1] do
	    min = m.min(min, self[i])
	 end
      else
	 min = self[1]:min()
	 for i = 2, self.shape[1] do
	    min = m.min(min, self[i]:min())
	 end
      end

   else
      min = Array( self.shape:remove(ax) )

      error("NotimplementedYet")
   end
   
   return min
end


-- Extract the maximum of an array along a given dimension
function Array:max(axis)
   local ax = ax_(axis)

   -- Returned maximum
   local max

   -- Now figure out what to do
   if ax == 0 then

      -- We simply need to extract the total minimum
      if #self.shape == 1 then
	 max = self[1]
	 for i = 2, self.shape[1] do
	    max = m.max(max, self[i])
	 end
      else
	 max = self[1]:max()
	 for i = 2, self.shape[1] do
	    min = m.max(max, self[i]:min())
	 end
      end

   else
      min = Array( self.shape:remove(ax) )

      error("NotimplementedYet")
   end
   
   return min
end

-- Sum along a given dimension (default total sum)
function Array:sum(axis)
   -- Get the actual axis
   local ax = ax_(axis)

   local sum
   if ax == 0 then
      sum = 0.
      for i = 1, self.shape[1] do
	 sum = sum + self[i]:sum(0)
      end
   elseif ax > #self.shape then
      error("flos.Array sum must be along an existing dimension")
   else

      -- Create the new array
      sum = Array( self.shape:remove(ax) )
      error("flos.Array not implemented yet")
   end

   return sum
end

-- Implementation of the cross product (only for Arrays with last dimension equal to 3)
-- Both the LHS and RHS must have the last dimension of length 3
function Array:cross(other)

   local sh = self.shape:align(other.shape)
   if sh == nil then
      error("flos.Array cross product does not have aligned shapes")
   end
   if self.shape[#self.shape] ~= 3 or other.shape[#other.shape] ~= 3 then
      error("flos.Array cross product requires the last dimension to have length 3")
   end

   local cross = Array( sh )

   if #cross.shape == 1 then
      cross[1] = self[2] * other[3] - self[3] * other[2]
      cross[2] = self[3] * other[1] - self[1] * other[3]
      cross[3] = self[1] * other[2] - self[2] * other[1]

   elseif self.shape == other.shape then
      -- We must do it on each of the arrays, in this case
      -- we can easily loop
      for i = 1, sh[1] do
	 cross[i] = self[i]:cross(other[i])
      end

   else

      error("flos.Array cross not implemented for non-equivalent shapes")
   end

   return cross
end


-- Create dot-product function.
-- For 1D arrays this returns a single value,
-- For ND arrays the shapes must fulfil self.shape[#self.shape] == other.shape[1],
--  as well as all dimensions self.shape[1:#self.shape-2] == other.shape[3:].reverse().
-- and a matrix-multiplication of the two inner most functions will prevail.
function Array.dot(lhs, rhs)

   -- The returned dot-product
   local dot

   -- Check if they are 1D Arrays
   if #lhs.shape == 1 and #rhs.shape == 1 then

      -- sum(lhs * rhs)
      if lhs.shape ~= rhs.shape then
	 error("flos.Array dot dimensions for 1D dot product are not the same")
      end
      
      -- This is a element wise product and sum
      dot = 0.
      for i = 1, lhs.shape[1] do
	 dot = dot + lhs[i] * rhs[i]
      end

   elseif #lhs.shape == 1 and #rhs.shape == 2 then

      -- lhs ^ T . rhs => vec

      if lhs.shape[1] ~= rhs.shape[1] then
	 error("flos.Array dot dimensions for 1D-2D dot product are not the same")
      end

      -- This is a element wise product and sum
      dot = Array( rhs.shape[2] )
      for j = 1, dot.shape[1] do
	 local v = 0.
	 for i = 1, lhs.shape[1] do
	    v = v + lhs[i] * rhs[i][j]
	 end
	 dot[j] = v
      end

   elseif #lhs.shape == 2 and #rhs.shape == 1 then

      -- lhs . rhs => vec

      if lhs.shape[2] ~= rhs.shape[1] then
	 error("flos.Array dot dimensions for 2D-1D dot product are not the same")
      end

      -- This is a element wise product and sum
      dot = Array( lhs.shape[1] )
      for i = 1, dot.shape[1] do
	 dot[i] = lhs[i]:dot(rhs)
      end

   elseif #lhs.shape == 2 and rhs.shape == 2 then

      -- Check that the shapes coincide
      if lhs.shape[2] ~= rhs.shape[1] then
	 error("flos.Array dot product 2D-2D must have inner dimensions equivalent lhs.shape[2] == rhs.shape[1]")
      end

      -- The easy case, align the shapes
      local sh = shape.Shape( lhs.shape[1], rhs.shape[2])
      dot = Array( sh )

      -- loop inner
      for j = 1 , lhs.shape[1] do
	 
	 -- Get local reference
	 local drow = dot[j]
	 local lrow = lhs[j]

	 -- loop outer
	 for i = 1 , rhs.shape[2] do

	    local v = 0.
	    for k = 1 , lhs.shape[2] do
	       v = v + lrow[k] * rhs[k][i]
	    end
	    drow[i] = v
	 end
      end

   else

      error("flos.Array dot for arrays with anything but 1 or 2 dimensions is not implemented yet")
      
   end

   return dot
      
end


-- Return a copy of self with the transposed array
function Array:transpose()

   -- Check dimensions, we cannot transpose a 1D array
   if #self.shape == 1 then
      error("flos.Array cannot transpose a vector, reshape, then transpose")
   end

   -- First create the reversed shape
   local sh = self.shape:reverse()

   -- Create return array
   local ret = Array( sh )

   -- Perform transpose
   local size = self:size()
   for i = 1, size do
      ret:_set_index_lin(size-i+1, self:_get_index_lin(i))
   end
   return ret
end


-- Perform all element wise operations
-- In the following we document the __add function, whereas the
-- later functions are compressed for visibility
function Array.__add(lhs, rhs)

   -- Create the return value
   local add

   -- Determine whether they are both the Arrays
   if isArray(lhs) and isArray(rhs) then

      -- Check if the shapes align (for element wise addition)
      local sh = lhs.shape:align(rhs.shape)
      if sh == nil then
	 error("flos.Array + requires the same shape for two different Arrays")
      end
      
      -- Create the return array
      add = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 add[i] = lhs[i] + rhs[i]
      end
      
   elseif isArray(lhs) then

      -- Element-wise additions
      add = Array( lhs.shape )

      for i = 1, lhs.shape[1] do
	 add[i] = lhs[i] + rhs
      end

   elseif isArray(rhs) then
      
      -- Element-wise additions
      add = Array( rhs.shape )

      for i = 1, rhs.shape[1] do
	 add[i] = lhs + rhs[i]
      end

   else
      error("flos.Array + could not figure out the types")
   end

   return add

end
function Array.__sub(lhs, rhs)
   local ret
   if isArray(lhs) and isArray(rhs) then
      local sh = lhs.shape:align(rhs.shape)
      if sh then
	 error("flos.Array - requires the same shape for two different Arrays")
      end
      ret = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 ret[i] = lhs[i] - rhs[i]
      end
   elseif isArray(lhs) then
      ret = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 ret[i] = lhs[i] - rhs
      end
   elseif isArray(rhs) then
      ret = Array( rhs.shape )
      for i = 1, rhs.shape[1] do
	 ret[i] = lhs - rhs[i]
      end
   else
      error("flos.Array - could not figure out the types")
   end
   return ret
end

function Array.__mul(lhs, rhs)
   local ret
   if isArray(lhs) and isArray(rhs) then
      local sh = lhs.shape:align(rhs.shape)
      if sh then
	 error("flos.Array * requires the same shape for two different Arrays")
      end
      ret = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 ret[i] = lhs[i] * rhs[i]
      end
   elseif isArray(lhs) then
      ret = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 ret[i] = lhs[i] * rhs
      end
   elseif isArray(rhs) then
      ret = Array( rhs.shape )
      for i = 1, rhs.shape[1] do
	 ret[i] = lhs * rhs[i]
      end
   else
      error("flos.Array * could not figure out the types")
   end
   return ret
end

function Array.__div(lhs, rhs)
   local ret
   if isArray(lhs) and isArray(rhs) then
      local sh = lhs.shape:align(rhs.shape)
      if sh then
	 error("flos.Array / requires the same shape for two different Arrays")
      end
      ret = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 ret[i] = lhs[i] / rhs[i]
      end
   elseif isArray(lhs) then
      ret = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 ret[i] = lhs[i] / rhs
      end
   elseif isArray(rhs) then
      ret = Array( rhs.shape )
      for i = 1, rhs.shape[1] do
	 ret[i] = lhs / rhs[i]
      end
   else
      error("flos.Array / could not figure out the types")
   end
   return ret
end

function Array:__unm()
   local ret = Array( self.shape:copy() )
   for i = 1, self.shape[1] do
      ret[i] = -self[i]
   end
   return ret
end

function Array.__pow(lhs, rhs)
   local ret
   if isArray(lhs) and isArray(rhs) then
      local sh = lhs.shape:align(rhs.shape)
      if sh then
	 error("flos.Array ^ requires the same shape for two different Arrays")
      end
      
      ret = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 ret[i] = lhs[i] ^ rhs[i]
      end
   elseif isArray(lhs) then
      -- Check for transposition
      if type(rhs) == "string" and rhs == "T" then
	 return lhs:transpose()
      end
      
      ret = Array( lhs.shape )
      for i = 1, lhs.shape[1] do
	 ret[i] = lhs[i] ^ rhs
      end
   elseif isArray(rhs) then
      -- Check for transposition
      if type(lhs) == "string" and lhs == "T" then
	 return rhs:transpose()
      end
      
      ret = Array( rhs.shape )
      for i = 1, rhs.shape[1] do
	 ret[i] = lhs ^ rhs[i]
      end
   else
      error("flos.Array ^ could not figure out the types")
   end
   return ret
end


-- Return table
return {
   ["Array"] = Array,
   ["isArray"] = isArray,
}
