-- Array2D library
-- Implementing simple Array2D classes

local _m  = require "math"

local cls = require "flos.base"
local Array = cls.Array
local Array1D = cls.Array1D
local Array2D = cls.Array2D

local istable = cls.istable

-- Create the stride selection 
-- Array2D[i..":"..j..":"..step]

function Array2D.__newindex(self, k, v)
   if string.lower(tostring(k)) == "all" then
      if istable(v) then
	 error("ERROR  Assigning all elements in a vector to a table"
		  .." is not allowed. They are assigned by reference.")
      end
      for i = 1 , #self do
	 self[i] = v
      end
   else
      if k < self.lbound[1] or self.ubound[1] < k then
	 error("ERROR  Your index is out of bounds")
      end
      rawset(self, k, v)
   end
end

function Array2D:initialize(ubound1, ubound2)
   local ub1, ub2
   if istable(ubound1) then
      ub1 = ubound1[1] or 1
      ub2 = ubound1[2] or 1
      ub2 = ubound2 or ub2
   else
      ub1 = ubound1 or 1
      ub2 = ubound2 or 1
   end
   if ub1 < 1 or ub2 < 1 then
      error("ERROR  You are initializing a vector with size <= 0.\nOnly array require positive upper bounds.")
   end
   -- Rawset is needed to not call the bounds-check
   rawset(self, "lbound", {1, 1})
   rawset(self, "ubound", {ub1, ub2})
   rawset(self, "size", {self.ubound[1] - self.lbound[1] + 1,
			 self.ubound[2] - self.lbound[2] + 1})
   for i = 1, ub1 do
      self[i] = Array1D:new(ub2)
   end
end

function Array2D.zeros(ubound1, ubound2)
   local new = Array2D:new(ubound1, ubound2)
   for i = 1, #new do
      for j = 1, #new[i] do
	 new[i][j] = 0.
      end
   end
   return new
end

function Array2D.ones(ubound1, ubound2)
   local new = Array2D:new(ubound1, ubound2)
   for i = 1, #new do
      for j = 1, #new[i] do
	 new[i][j] = 1.
      end
   end
   return new
end

-- Return the absolute value of all elements
function Array2D:abs()
   local new = Array2D:new(self.size)
   for i = 1, #new do
      for j = 1, #new[i] do
	 new[i][j] = _m.abs(self[i][j])
      end
   end
   return new
end

function Array2D.from(tbl)
   local new
   if istable(tbl[1]) then
      new = Array2D:new(#tbl, #tbl[1])
      for i = 1, #tbl do
	 for j = 1, #tbl[i] do
	    new[i][j] = tbl[i][j]
	 end
      end
   else
      local n = #tbl
      new = Array1D:new(n)
      for i = 1, #tbl do
	 new[i] = tbl[i]
      end
      new = new:reshape(-1, 1)
   end
   return new
end


function Array2D:copy()
   local new = Array2D:new(self.size)
   for i = 1, self.size[1] do
      for j = 1, self.size[2] do
	 new[i][j] = self[i][j]
      end
   end
   return new
end

function Array2D:reshape (...)
   -- Grab variable arguments
   local arg = {...}
   -- Number of arguments passed
   local narg = #arg

   -- total size of this array
   local ntot = self.size[1] * self.size[2]
   -- Returned array
   local new

   if narg == 0 then
      new = self:copy()

   elseif narg == 1 then
      -- Downscaling
      if arg[1] == -1 then
	 arg[1] = ntot
      end
      if arg[1] ~= ntot then
	 error("Array2D: reshape, elements from to does not coincide")
      end
      
      new = Array1D:new(arg[1])
      local k = 0
      for i = 1, self.size[1] do
	 for j = 1, self.size[2] do
	    k = k + 1
	    new[k] = self[i][j]
	 end
      end

   elseif narg == 2 then
      if arg[1] * arg[2] ~= ntot then
	 error("Array2D: reshape, elements from to does not coincide")
      end
      
      new = Array2D:new(arg)
      local k, l = 1, 0
      for i = 1, arg[1] do
	 for j = 1, arg[2] do
	    l = l + 1
	    if l > self.size[2] then
	       l = 1
	       k = k + 1
	    end
	    new[i][j] = self[k][l]
	 end
      end

   else
      error("Array2D: reshaping not implemneted")
      
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
      -- We must have a number, fake the table (fake double entries
      -- by having a double metatable
      local mt = setmetatable({size = 1, class = false},
			       { __index = 
				    function(t, k)
				       return val
				    end
			       })
      return setmetatable({size = {1, 1}, class = false},
			  { __index = 
			       function(t, k)
				  return mt
			       end
			  })
   end
end

local function op_elem(lhs, rhs)
   -- an option parser for the functions
   -- that require ELEMENT wise operations
   -- correct information
   local t = {}
   local s = 0
   local ls , rs = nil , nil
   if cls.instanceOf(lhs, Array2D) then
      ls = lhs.size
   else
      ls = 1
   end
   t.lhz = ensuretable(lhs)
   if cls.instanceOf(rhs, Array2D) then
      rs = rhs.size
   else
      rs = 1
   end
   t.rhz = ensuretable(rhs)
   if istable(ls) and istable(rs) then
      if ls[1] ~= rs[1] or ls[2] ~= rs[2] then
	 if ls ~= 1 and rs ~= 1 then
	    error("ERROR  Array2D dimensions incompatible")
	 end
      end
      t.size = ls
      
   elseif istable(ls) then
      if rs ~= 1 then
	 error("ERROR  Array2D dimensions incompatible")
      end
      t.size = ls
      
   elseif istable(rs) then
      if ls ~= 1 then
	 error("ERROR  Array2D dimensions incompatible")
      end
      t.size = rs
      
   end
   return t
end

-- Length lookup
-- /for i = 1 , #Array2D do\
function Array2D.__len(self)
   return self.size[1]
end


-- Implementation of norm function
function Array2D:norm()
   local n = Array1D:new(self.size[1])
   for i = 1 , #self do
      local nn = 0.
      for j = 1, self.size[2] do
	 nn = nn + self[i][j] * self[i][j]
      end
      n[i] = _m.sqrt(nn)
   end
   return n
end

-- Implementation of the (flattened) dot product
function Array2D.dot(lhs, rhs)

   function size_err(str)
      error("Array2D.dot: wrong dimensions. " .. str)
   end

   -- Returned value
   local v
   
   -- First we figure out if the dot (matrix-product)
   if cls.instanceOf(lhs, Array1D) then
      if cls.instanceOf(rhs, Array1D) then
	 -- An explicit call of the Array2D dot product
	 -- would probably be the same as doing the
	 --  x . y^T

	 -- vector . vector -> matrix
	 if lhs.size ~= rhs.size then
	    size_err("1D-1D")
	 end
	 v = Array2D:new(lhs.size, lhs.size)
	 for i = 1, #lhs do
	    for j = 1, #lhs do
	       v[i][j] = lhs[i] * rhs[j]
	    end
	 end
	 
      elseif cls.instanceOf(rhs, Array2D) then
	 -- vector . matrix
	 if lhs.size ~= rhs.size[1] then
	    size_err("1D-2D")
	 end
	 v = Array1D:new(rhs.size[2])
	 for j = 1 , #v do
	    local vv = 0.
	    for i = 1, #lhs do
	       vv = vv + lhs[i] * rhs[i][j]
	    end
	    v[j] = vv
	 end
	 
      else
	 -- simple scaling
	 v = lhs * rhs
      end

   elseif cls.instanceOf(lhs, Array2D) then
      if cls.instanceOf(rhs, Array1D) then

	 -- matrix . vector
	 if lhs.size[2] ~= rhs.size then
	    size_err("2D-1D")
	 end
	 v = Array1D:new(lhs.size[1])
	 for j = 1 , #v do
	    local vv = 0.
	    for i = 1, #rhs do
	       vv = vv + lhs[j][i] * rhs[i]
	    end
	    v[j] = vv
	 end

      elseif cls.instanceOf(rhs, Array2D) then

	 -- matrix . matrix
	 if lhs.size[2] ~= rhs.size[1] then
	    size_err("2D-2D")
	 end
	 v = Array2D:new(lhs.size[1], rhs.size[2])
	 for j = 1 , v.size[1] do
	    -- Get local references
	    local lrow = lhs[j]
	    for i = 1 , v.size[2] do

	       local vv = 0.
	       for k = 1 , lhs.size[2] do
		  vv = vv + lrow[k] * rhs[k][i]
	       end
	       v[j][i] = vv
	       
	    end
	 end

      else
	 -- Simple scaling
	 v = lhs * rhs
      end
   else
      -- Simple scaling
      v = lhs * rhs
   end
   
   return v
end

--[[
   We need to create all the different methods for 
   numerical stuff
--]]
function Array2D.__add(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D:new(t.size)
   
   -- We have now created the corrrect new vector for containing the
   -- data
   -- Loop over the vector size
   for i = 1 , #v do
      for j = 1, #v[i] do
	 v[i][j] = t.lhz[i][j] + t.rhz[i][j]
      end
   end
   return v
end

function Array2D.__sub(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D:new(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] - t.rhz[i]
   end
   return v
end

function Array2D.__mul(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D:new(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] * t.rhz[i]
   end
   return v
end

function Array2D.__div(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D:new(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] / t.rhz[i]
   end
   return v
end

function Array2D.__pov(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D:new(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] ^ t.rhz[i]
   end
   return v
end

function Array2D:__unm()
   local v = Array2D:new(self.size)
   for i = 1 , #self do
      for j = 1, #self[i] do
	 v[i][j] = -self[i][j]
      end
   end
   return v
end

function Array2D.__tostring(self)
   local s = "["
   for i = 1, #self do
      s = s .. "[" .. tostring(self[i][1])
      for j = 2 , #self[i] do
	 s = s .. ", " .. tostring(self[i][j])
      end
      if i < #self then
	 s = s .. "]\n "
      end
   end
   return s .. ']]'
end

function Array2D.__pow(lhs, rhs)
   if type(rhs) == "string" then
      -- it may be transpose we are after
      if rhs == "T" then
	 -- Create the transposed array
	 local v = Array2D:new(lhs.size[2], lhs.size[1])
	 for i = 1 , #v do
	    for j = 1 , #v[i] do
	       v[i][j] = lhs[j][i]
	    end
	 end
	 return v
      end
      error("Unknown string power")
   end
	 
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D:new(t.size)
   for i = 1 , #v do
      v[i] = t.lhz[i] ^ t.rhz[i]
   end
   return v
end

return Array2D
