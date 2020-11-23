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
local TNEB = mc.class("TNEB", _NEB)
--- Instantiating a new TNEB` object.
   --==============================================
   -- Defining TNEB Temperature
   --==============================================   
   -- For Adding Temperature Dependet
function TNEB:initialize(images,tbl)
   -- Convert the remaining arguments to a table
   local tbl = tbl or {}
     -- Copy all images over
   local size_img = #images[1].R
   for i = 1, #images do
      self[i-1] = images[i]
      self.zeros=images[i].R- images[i].R
      if #images[i].R ~= size_img then
	 error("TNEB: images does not have same size of geometries!")
      end
   end
   -- store the number of images (without the initial and final)
   self.n_images = #images - 2
   -- This is _bad_ practice, however,
   -- the middleclass system does not easily enable overwriting
   -- the __index function (because it uses it)
   self.initial = images[1]
   self.final = images[#images]
   --self.neb_type = "TDCINEB" --working
   --==============================================
   -- Defining NEB Type
   --==============================================
   --local nt= tbl.neb_type
   --if nt == nil then
   --   self.neb_type="VCCINEB"
   --else
   -- self.neb_type = nt
   --end
   --self.neb_type = "VCCINEB"
   --==============================================
   -- Defining VCNEB Label
   --==============================================
   
   --==============================================
   -- Defining VCNEB Temperature
   --==============================================   
   -- For Adding Temperature Dependet
   local nk =tbl.neb_temp
   if nk == nil then
     self.neb_temp = 0.0
   else
     self.neb_temp= nk
   end
   self.boltzman=8.617333262*10^(-5)
   self.beta=1.0/(self.neb_temp*self.boltzman)
   --==============================================
   -- Defining Number of Climing Image
   --==============================================    
   --self.old_DM_label=""
   --self.current_DM_label=""
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

   
   
   
   
--   local nk =tbl.neb_temp
--   if nk == nil then
--     self.neb_temp = 0.0
--   else
--     self.neb_temp= nk
--   end
--   self.boltzman=8.617333262*10^(-5)
--   self.beta=1.0/(self.neb_temp*self.boltzman)
   
   
--- Calculate the tangent of a given image
-- @int image the image to calculate the tangent of
-- @return tangent force
--- Calculate the perpendicular force of a given image
-- @int image the image to calculate the perpendicular force of
-- @return perpendicular force
-- Edited to adopt the VCNEB
--- Calculate the curvature of the force with regards to the tangent
-- @int image the image to calculate the curvature of

function TNEB:neb_force(image)
   self:_check_image(image)
   local NEB_F
   local TDNEB_F
   -- Only run Climbing image after a certain amount of steps (robustness)
   -- Typically this number is 5.
   --===================================================================
   --Adding Temperature Dependent Climing Image-Nudged Elastic Band
   --===================================================================
     if self.niter > self._climbing and self:climbing(image) then
          local F = self[image].F
          if self:tangent(image):norm(0)==0.0 then
               NEB_F = F
          else 
               NEB_F = F - 2 * F:project( self:tangent(image) )
          end
     else
          --NEB_NORM = F - self:perpendicular_force(image)
          TDNEB_F = self:perpendicular_force(image)-(self:curvature(image)/self.beta) * NEB_NORM
          NEB_F = TDNEB_F + self:spring_force(image) 
     end
     return NEB_F
   end
--- Query the current force (same as `NEB:force` but with IO included)
-- @int image the image
-- @return force
function TNEB:force(image, IO)
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
      f = io.open( ("TNEB.%d.R"):format(image), "a")
      self[image].R:savetxt(f)
      f:close()
      -- Forces before (ie .F)
      f = io.open( ("TNEB.%d.F"):format(image), "a")
      F:savetxt(f)
      f:close()
      -- Perpendicular force
      f = io.open( ("TNEB.%d.F.P"):format(image), "a")
      perp_F:savetxt(f)
      f:close()      
      -- Spring force
      f = io.open( ("TNEB.%d.F.S"):format(image), "a")
      spring_F:savetxt(f)
      f:close()
      -- NEB Force
      f = io.open( ("TNEB.%d.F.NEB"):format(image), "a")
      NEB_F:savetxt(f)
      f:close()
      -- Tangent
      f = io.open( ("TNEB.%d.T"):format(image), "a")
      tangent:savetxt(f)
      f:close()
      -- dR - previous reaction coordinate
      f = io.open( ("TNEB.%d.dR_prev"):format(image), "a")
      self:dR(image-1, image):savetxt(f)
      f:close()
      -- dR - next reaction coordinate
      f = io.open( ("TNEB.%d.dR_next"):format(image), "a")
      self:dR(image, image+1):savetxt(f)
      f:close()
   end
   -- Fake return to test
   return NEB_F   
end
--- Store the current step of the NEB iteration with the appropriate results
function TNEB:save(IO)
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
   local f = io.open("TNEB.results", "a")
   dat:savetxt(f)
   f:close()
end

--- Initialize all files that will be written to
function TNEB:init_files()   
   -- We clean all image data for a new run
   local function new_file(fname, ...)
      local f = io.open(fname, 'w')
      local a = {...}
      for _, v in pairs(a) do
	 f:write("# " .. v .. "\n")
      end
      f:close()
   end
   new_file("TNEB.results", "NEB results file",
	    "Image reaction-coordinate Energy E-diff Curvature F-max(atom)")   
   for img = 1, self.n_images do
      new_file( ("TNEB.%d.R"):format(img), "Coordinates")
      new_file( ("TNEB.%d.F"):format(img), "Constrained force")
      new_file( ("TNEB.%d.F.P"):format(img), "Perpendicular force")
      new_file( ("TNEB.%d.F.S"):format(img), "Spring force")
      new_file( ("TNEB.%d.F.NEB"):format(img), "Resulting NEB force")
      new_file( ("TNEB.%d.T"):format(img), "NEB tangent")
      new_file( ("TNEB.%d.dR_prev"):format(img), "Reaction distance (previous)")
      new_file( ("TNEB.%d.dR_next"):format(img), "Reaction distance (next)")
   end
end
--- Print to screen some information regarding the NEB algorithm
function TNEB:info() 
   print ("=================================================") 
   print (" The Temperature Dependent CI-DNEB(VCDNEB) Method   ")
   print ("=================================================")
   print ("The Temperature is : ".. self.neb_temp .. " K")
   print("TNEB has " .. self.n_images)
   print("TNEB uses climbing after " .. self._climbing .. " steps")
   local tmp = array.Array( self.n_images + 1 )
   tmp[1] = self:dR(0, 1):norm(0)
   for i = 2, self.n_images + 1 do
      tmp[i] = tmp[i-1] + self:dR(i-1, i):norm(0)
   end
   print("TNEB reaction coordinates: ")
   print(tostring(tmp))
   local tmp = array.Array( self.n_images )
   for i = 1, self.n_images do
      tmp[i] = self.k[i]
   end
   print("TNEB spring constant: ")
   print(tostring(tmp))
end
-- Calculatin Perpendicular Spring force
function TNEB:perpendicular_spring_force(image)
  self:_check_image(image)
  if self:tangent(image):norm(0)==0.0 then
     return  self:spring_force(image)
  else
  local PS=self:spring_force(image):project(self:tangent(image))
     return self:spring_force(image)-PS
  end
end
function TNEB:file_exists(name)--name
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

return TNEB
