---
-- NEB class
-- @classmod NEB

local m = require "math"
local mc = require "flos.middleclass.middleclass"

local array = require "flos.num"
local ferror = require "flos.error"
local error = ferror.floserr
local _NEB = require "flos.special.neb"

-- Create the NEB class (inheriting the Optimizer construct)
local VCNEB = mc.class("VCNEB", _NEB)
--- Instantiating a new VCNEB` object.
function VCNEB:initialize(images,tbl)
   -- Convert the remaining arguments to a table
   local tbl = tbl or {}
     -- Copy all images over
   local size_img = #images[1].R
   for i = 1, #images do
      self[i-1] = images[i]
      self.zeros=images[i].R- images[i].R
      if #images[i].R ~= size_img then
	 error("VCNEB: images does not have same size of geometries!")
      end
   end
   -- store the number of images (without the initial and final)
   self.n_images = #images - 2
   -- This is _bad_ practice, however,
   -- the middleclass system does not easily enable overwriting
   -- the __index function (because it uses it)
   self.initial = images[1]
   self.final = images[#images]
      -- an integer that describes when the climbing image
   -- may be used, make large enough to never set it
   local cl = tbl.climbing or 5
   if cl == false then
      self._climbing = 1000000000000
   elseif cl == true then
      -- We use the default value
      self._climbing = 5
   else
      -- Counter for climbing
      self._climbing = cl
   end
   -- Set the climbing energy tolerance
   self.climbing_tol = tbl.climbing_tol or 0.005 -- if the input is in eV/Ang this is 5 meV
   self.niter = 0
   --==============================================
   -- Defining spring Constant
   --==============================================   
   -- One should also attach the spring-constant
   -- It currently defaults to 5
   local kl = tbl.k or 10
   if type(kl) == "table" then
      self.k = kl
   else
      self.k = setmetatable({},
			    {
			       __index = function(t, k)
				  return kl
			       end
			    })
   end
   self:init_files()   
end
--- Calculate the tangent of a given image
-- @int image the image to calculate the tangent of
-- @return tangent force
-- The Tangent Edited for VCNEB
-- In case of VCNEB started with the same unit vectors the it should consistent
function VCNEB:tangent(image)
   self:_check_image(image)
   -- Determine energies of relevant images
   local E_prev = self[image-1].E
   local E_this = self[image].E
   local E_next = self[image+1].E
   -- Determine position differences
   local dR_prev = self:dR(image-1, image)
   local dR_next = self:dR(image, image+1)
   local dR_this = self:dR(image, image)
   -- Returned value
   local tangent
   -- Determine relevant energy scenario
   --if dR_next:norm(0) == 0.0 or dR_prev:norm(0)==0.0 or dR_this:norm(0)==0.0  then
   --   tangent = dR_this
   --   return tangent
   if E_next > E_this and E_this > E_prev then
      tangent = dR_next
      if dR_next:norm(0) == 0.0  then
        return tangent
      else
        return tangent / tangent:norm(0)
      end
   elseif E_next < E_this and E_this < E_prev then      
      tangent = dR_prev
      if dR_prev:norm(0)==0.0 then
        return tangent
      else
        return tangent / tangent:norm(0)
      end   
   else      
      -- We are at extremum, so mix
      local dEmax = m.max( m.abs(E_next - E_this), m.abs(E_prev - E_this) )
      local dEmin = m.min( m.abs(E_next - E_this), m.abs(E_prev - E_this) )      
      if E_next > E_prev then
         tangent = dR_next * dEmax + dR_prev * dEmin
         if dR_next:norm(0) == 0.0 or dR_prev:norm(0)==0.0 then
             return tangent
         else
         return tangent / tangent:norm(0)
         end
      else
	       tangent = dR_next * dEmin + dR_prev * dEmax
         if dR_next:norm(0) == 0.0 or dR_prev:norm(0)==0.0 then
             return tangent
         else
             return tangent / tangent:norm(0)
         end      
      end      
   end
   -- At this point we have a tangent,
   -- now normalize and return it
   
      --return tangent / tangent:norm(0)
   --end
end

--- Calculate the spring force of a given image
-- @int image the image to calculate the spring force of
-- @return spring force
-- function NEB:spring_force(image)
--   self:_check_image(image)
   -- Determine position norms
--   local dR_prev = self:dR(image-1, image):norm(0)
--   local dR_next = self:dR(image, image+1):norm(0)   
   -- Set spring force as F = k (R1-R2) * tangent
   --if dR_prev==0.0 or dR_next==0.0 then
   --  return self:tangent(image) --self.k[image] * (dR_next - dR_prev) * self:tangent(image)
   --else
 --   return self.k[image] * (dR_next - dR_prev) * self:tangent(image)  
   --end
--end



--- Calculate the perpendicular force of a given image
-- @int image the image to calculate the perpendicular force of
-- @return perpendicular force
-- Edited to adopt the VCNEB
function VCNEB:perpendicular_force(image)
   self:_check_image(image)
   if self:tangent(image):norm(0)==0.0 then
     return self[image].F
   else
   -- Subtract the force projected onto the tangent to get the perpendicular force
   local P = self[image].F:project(self:tangent(image))
   return self[image].F - P --self:tangent(image) 
   end
end
--- Calculate the curvature of the force with regards to the tangent
-- @int image the image to calculate the curvature of



function VCNEB:neb_force(image)
   self:_check_image(image)
   local NEB_F
   local DNEB_F
   local TDNEB_F
   -- Only run Climbing image after a certain amount of steps (robustness)
   -- Typically this number is 5.
   --===================================================================
      --Adding Variable Cell Climing Image Nudged Elastic Band
   --===================================================================
     if self.niter > self._climbing and self:climbing(image) then
       local F = self[image].F
       NEB_F = F - 2 * F:project( self:tangent(image) )
     else
       DNEB_F = 0.0
       NEB_F = self:perpendicular_force(image) + self:spring_force(image) + DNEB_F
     end
     return NEB_F
   end
--- Query the current force (same as `NEB:force` but with IO included)
-- @int image the image
-- @return force
function VCNEB:force(image, IO)
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
      f = io.open( ("VCNEB.%d.R"):format(image), "a")
      self[image].R:savetxt(f)
      f:close()
      -- Forces before (ie .F)
      f = io.open( ("VCNEB.%d.F"):format(image), "a")
      F:savetxt(f)
      f:close()
      -- Perpendicular force
      f = io.open( ("VCNEB.%d.F.P"):format(image), "a")
      perp_F:savetxt(f)
      f:close()      
      -- Spring force
      f = io.open( ("VCNEB.%d.F.S"):format(image), "a")
      spring_F:savetxt(f)
      f:close()
      -- NEB Force
      f = io.open( ("VCNEB.%d.F.NEB"):format(image), "a")
      NEB_F:savetxt(f)
      f:close()
      -- Tangent
      f = io.open( ("VCNEB.%d.T"):format(image), "a")
      tangent:savetxt(f)
      f:close()
      -- dR - previous reaction coordinate
      f = io.open( ("VCNEB.%d.dR_prev"):format(image), "a")
      self:dR(image-1, image):savetxt(f)
      f:close()
      -- dR - next reaction coordinate
      f = io.open( ("VCNEB.%d.dR_next"):format(image), "a")
      self:dR(image, image+1):savetxt(f)
      f:close()
   end
   -- Fake return to test
   return NEB_F   
end
--- Store the current step of the NEB iteration with the appropriate results
function VCNEB:save(IO)
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
   local f = io.open("VCNEB.results", "a")
   dat:savetxt(f)
   f:close()
end

--- Initialize all files that will be written to
function VCNEB:init_files()   
   -- We clean all image data for a new run
   local function new_file(fname, ...)
      local f = io.open(fname, 'w')
      local a = {...}
      for _, v in pairs(a) do
	 f:write("# " .. v .. "\n")
      end
      f:close()
   end
   new_file("VCNEB.results", "NEB results file",
	    "Image reaction-coordinate Energy E-diff Curvature F-max(atom)")   
   for img = 1, self.n_images do
      new_file( ("VCNEB.%d.R"):format(img), "Coordinates")
      new_file( ("VCNEB.%d.F"):format(img), "Constrained force")
      new_file( ("VCNEB.%d.F.P"):format(img), "Perpendicular force")
      new_file( ("VCNEB.%d.F.S"):format(img), "Spring force")
      new_file( ("VCNEB.%d.F.NEB"):format(img), "Resulting NEB force")
      new_file( ("VCNEB.%d.T"):format(img), "NEB tangent")
      new_file( ("VCNEB.%d.dR_prev"):format(img), "Reaction distance (previous)")
      new_file( ("VCNEB.%d.dR_next"):format(img), "Reaction distance (next)")
   end
end
--- Print to screen some information regarding the NEB algorithm
function VCNEB:info()
   print ("============================================") 
   print (" The Variable Cell NEB (VC-NEB) method  ")
   print ("============================================") 
  
   print("VCNEB Number of Images :  " .. self.n_images)
   print("VCNEB Use Climbing After : " .. self._climbing .. " Steps")
   local tmp = array.Array( self.n_images + 1 )
   tmp[1] = self:dR(0, 1):norm(0)
   for i = 2, self.n_images + 1 do
      tmp[i] = tmp[i-1] + self:dR(i-1, i):norm(0)
   end
   print("VCNEB Reaction Coordinates: ")
   print(tostring(tmp))
   local tmp = array.Array( self.n_images )
   for i = 1, self.n_images do
      tmp[i] = self.k[i]
   end
   print("VCNEB Spring Constant: ")
   print(tostring(tmp))
end
-- Calculatin Perpendicular Spring force
function VCNEB:perpendicular_spring_force(image)
  self:_check_image(image)
  if self:tangent(image):norm(0)==0.0 then
     return  self:spring_force(image)
  else
  local PS=self:spring_force(image):project(self:tangent(image))
     return self:spring_force(image)-PS
  end
end
function VCNEB:file_exists(name)--name
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

return VCNEB
