---
-- VCDNEB class
-- @classmod VC-DNEB

local m = require "math"
local mc = require "flos.middleclass.middleclass"

local array = require "flos.num"
local ferror = require "flos.error"
local error = ferror.floserr
local _NEB = require "flos.special.vcneb"

-- Create the NEB class (inheriting the Optimizer construct)
local VCDNEB = mc.class("VCDNEB", _NEB)
--- Instantiating a new VCNEB` object.

--- Calculate the tangent of a given image
-- @int image the image to calculate the tangent of
-- @return tangent force
-- The Tangent Edited for VC-DNEB
-- In case of VC-DNEB started with the same unit vectors the it should consistent

--- Calculate the spring force of a given image
-- @int image the image to calculate the spring force of
-- @return spring force
--- Calculate the curvature of the force with regards to the tangent
-- @int image the image to calculate the curvature of

--- Calculate perpendicular spring force for a given image
-- @int image image to calculate the perpendicular spring force of
-- @return the perpendicular spring force
function VCDNEB:perpendicular_spring_force(image)
   -- We don't need to check image (these function calls does exactly that)
   local S_F = self:spring_force(image)

   -- Return the new perpendicular spring force
   return S_F - S_F:project( self:tangent(image) )
end

function VCDNEB:neb_force(image)
   -- Calculate *original* NEB force
   local NEB_F = _NEB.neb_force(self, image)

   -- Only correct in case we are past climbing
   if self.niter > self._climbing and self:climbing(image) then
      return NEB_F
   end

   local PS_F = self:perpendicular_spring_force(image)
   local P_F = self:perpendicular_force(image)
   
   -- This is equivalent to:
   --   flatdot(PS_F, P_F) / norm(P_F)^2 * P_F .* P_F
   -- with .* being the elementwise multiplication
   return NEB_F + PS_F - PS_F:project( P_F ) * P_F
end

--- Query the current force (same as `NEB:force` but with IO included)
-- @int image the image
-- @return force
function VCDNEB:force(image, IO)
   self:_check_image(image)   
   if image == 1 then
      -- Increment step-counter
      self.niter = self.niter + 1
   end
   local F = self[image].F
   local tangent = self:tangent(image)
   local perp_F = self:perpendicular_force(image)
   local spring_F = self:spring_force(image)
   local NEB_F = self:neb_force(image)
    -- Things I want to output in files as control (all in 3xN format)
   if IO then
      local f
      -- Current coordinates (ie .R)
      f = io.open( ("VCDNEB.%d.R"):format(image), "a")
      self[image].R:savetxt(f)
      f:close()
      -- Forces before (ie .F)
      f = io.open( ("VCDNEB.%d.F"):format(image), "a")
      F:savetxt(f)
      f:close()
      -- Perpendicular force
      f = io.open( ("VCDNEB.%d.F.P"):format(image), "a")
      perp_F:savetxt(f)
      f:close()      
      -- Spring force
      f = io.open( ("VCDNEB.%d.F.S"):format(image), "a")
      spring_F:savetxt(f)
      f:close()
      -- NEB Force
      f = io.open( ("VCDNEB.%d.F.NEB"):format(image), "a")
      NEB_F:savetxt(f)
      f:close()
      -- Tangent
      f = io.open( ("VCDNEB.%d.T"):format(image), "a")
      tangent:savetxt(f)
      f:close()
      -- dR - previous reaction coordinate
      f = io.open( ("VCDNEB.%d.dR_prev"):format(image), "a")
      self:dR(image-1, image):savetxt(f)
      f:close()
      -- dR - next reaction coordinate
      f = io.open( ("VCDNEB.%d.dR_next"):format(image), "a")
      self:dR(image, image+1):savetxt(f)
      f:close()
   end
   -- Fake return to test
   return NEB_F   
end
--- Store the current step of the NEB iteration with the appropriate results
function VCDNEB:save(IO)
   -- If we should not do IO, return immediately
   if not IO then
      return
   end
   -- local E0
   local E0 = self[0].E
   -- Now setup the matrix to write the NEB-results
   local dat = array.Array( self.n_images + 2, 6)
   for i = 0, self.n_images + 1 do
      local row = dat[i+1]
      -- image number (0 for initial, n_images + 1 for final)
      row[1] = i
      -- Accumulated reaction coordinate
      if i == 0 then
	 row[2] = 0.
      else
	 row[2] = dat[i][2] + self:dR(i-1, i):norm(0)
      end
      -- Total energy of current iteration
      row[3] = self[i].E
      -- Energy difference from initial image
      row[4] = self[i].E - E0
      -- Image curvature
      if i == 0 or i == self.n_images + 1 then
	 row[5] = 0.
      else
	 row[5] = self:curvature(i)
      end
      -- Vector-norm of maximum force of the NEB-force
      if i == 0 or i == self.n_images + 1 then
	 row[6] = 0.
      else
	 row[6] = self:neb_force(i):norm():max()
      end
   end
   local f = io.open("VCDNEB.results", "a")
   dat:savetxt(f)
   f:close()
end

--- Initialize all files that will be written to
function VCDNEB:init_files()   
   -- We clean all image data for a new run
   local function new_file(fname, ...)
      local f = io.open(fname, 'w')
      local a = {...}
      for _, v in pairs(a) do
	 f:write("# " .. v .. "\n")
      end
      f:close()
   end
   new_file("VCDNEB.results", "NEB results file",
	    "Image reaction-coordinate Energy E-diff Curvature F-max(atom)")   
   for img = 1, self.n_images do
      new_file( ("VCDNEB.%d.R"):format(img), "Coordinates")
      new_file( ("VCDNEB.%d.F"):format(img), "Constrained force")
      new_file( ("VCDNEB.%d.F.P"):format(img), "Perpendicular force")
      new_file( ("VCDNEB.%d.F.S"):format(img), "Spring force")
      new_file( ("VCDNEB.%d.F.NEB"):format(img), "Resulting NEB force")
      new_file( ("VCDNEB.%d.T"):format(img), "NEB tangent")
      new_file( ("VCDNEB.%d.dR_prev"):format(img), "Reaction distance (previous)")
      new_file( ("VCDNEB.%d.dR_next"):format(img), "Reaction distance (next)")
   end
end
--- Print to screen some information regarding the NEB algorithm
function VCDNEB:info()
-- print (************************** End: TS CHECKS AND WARNINGS **************************)
   print ("***************** The Variable Cell Double NEB Method *******************")
   
   --print ("============================================") 
   --print ("   The Variable Cell Double NEB Method      ")
   --print ("============================================") 
  
  
   print("VC-DNEB Number of Images : " .. self.n_images)
   print("VC-DNEB Use Climbing After :" .. self._climbing .. " Steps")
   local tmp = array.Array( self.n_images + 1 )
   tmp[1] = self:dR(0, 1):norm(0)
   for i = 2, self.n_images + 1 do
      tmp[i] = tmp[i-1] + self:dR(i-1, i):norm(0)
   end
   print("VC-DNEB Reaction Coordinates: ")
   print(tostring(tmp))
   local tmp = array.Array( self.n_images )
   for i = 1, self.n_images do
      tmp[i] = self.k[i]
   end
   print("VC-DNEB Cpring Constant: ")
   print(tostring(tmp))
end
-- Calculatin Perpendicular Spring force
function VCDNEB:perpendicular_spring_force(image)
  self:_check_image(image)
  if self:tangent(image):norm(0)==0.0 then
     return  self:spring_force(image)
  else
  local PS=self:spring_force(image):project(self:tangent(image))
     return self:spring_force(image)-PS
  end
end
function VCDNEB:file_exists(name)--name
   --local name
   --DM_name=tostring(name)
   DM_name=name
   --print ("DM_name is :" .. DM_name)
   local check
   --local DM_name = name
   local f = io.open(DM_name, "r") --name
   if f ~= nil then
      io.close(f)
      --check=true
      --print("TRUE: The file ".. DM_name..  " Exist!")
      return true
   else
      --print("False: The file ".. DM_name..  " Doesn't Exist!")
      return false
     --check=false      
   end
   --return check
end

return VCDNEB
