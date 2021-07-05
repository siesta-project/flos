---
-- D-NEB class
-- @classmod DNEB

local mc = require "flos.middleclass.middleclass"
local _NEB = require "flos.special.neb"
local array = require "flos.num"

-- Create the D-NEB class
local DNEB = mc.class("DNEB", _NEB)


--- Calculate perpendicular spring force for a given image
-- @int image image to calculate the perpendicular spring force of
-- @return the perpendicular spring force
function DNEB:perpendicular_spring_force(image)
   -- We don't need to check image (these function calls does exactly that)
   local S_F = self:spring_force(image)

   -- Return the new perpendicular spring force
   return S_F - S_F:project( self:tangent(image) )
end


-- Now we need to overwrite the calculation of the NEB-force

--- Calculate the resulting NEB force of a given image
-- @int image the image to calculate the NEB force of
-- @return NEB force
function DNEB:neb_force(image)
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


--- Print to screen some information regarding the NEB algorithm
function DNEB:info()
   print("DNEB Number of Images :  " .. self.n_images)
   print("DNEB Use Climbing After : " .. self._climbing .. " Steps")
   local tmp = array.Array( self.n_images + 1 )
   --tmp[1] = self:dR(0, 1):norm(0)
   tmp[1] = self:dR(0, 1):norm(0)
   for i = 2, self.n_images + 1 do
      tmp[i] = tmp[i-1] + self:dR(i-1, i):norm(0)
   end
   print("DNEB Reaction Coordinates: ")
   print(tostring(tmp))
   local tmp = array.Array( self.n_images )
   for i = 1, self.n_images do
      tmp[i] = self.k[i]
   end
   print("DNEB spring constant: ")
   print(tostring(tmp))
end


function DNEB:force(image, IO)
   self:_check_image(image)

   if image == 1 then
      -- Increment step-counter
      self.niter = self.niter + 1
   end

   local NEB_F = self:neb_force(image)

   -- Things I want to output in files as control (all in 3xN format)
   if IO then
      local f

      -- Current coordinates (ie .R)
      f = io.open( ("DNEB.%d.R"):format(image), "a")
      self[image].R:savetxt(f)
      f:close()

      -- Forces before (ie .F)
      f = io.open( ("DNEB.%d.F"):format(image), "a")
      self[image].F:savetxt(f)
      f:close()

      -- Perpendicular force
      f = io.open( ("DNEB.%d.F.P"):format(image), "a")
      self:perpendicular_force(image):savetxt(f)
      f:close()
      
      -- Spring force parallel
      f = io.open( ("DNEB.%d.F.S.parallel"):format(image), "a")
      self:spring_force(image):savetxt(f)
      f:close()
      
      -- Spring force perdpendicular
      f = io.open( ("DNEB.%d.F.S.perpendicular"):format(image), "a")
      self:perpendicular_spring_force(image):savetxt(f)
      f:close()

      -- NEB Force
      f = io.open( ("DNEB.%d.F.NEB"):format(image), "a")
      NEB_F:savetxt(f)
      f:close()

      -- Tangent
      f = io.open( ("DNEB.%d.T"):format(image), "a")
      self:tangent(image):savetxt(f)
      f:close()

      -- dR - previous reaction coordinate
      f = io.open( ("DNEB.%d.dR_prev"):format(image), "a")
      self:dR(image-1, image):savetxt(f)
      f:close()

      -- dR - next reaction coordinate
      f = io.open( ("DNEB.%d.dR_next"):format(image), "a")
      self:dR(image, image+1):savetxt(f)
      f:close()

   end

   -- Fake return to test
   return NEB_F
   
end


function DNEB:init_files()
   
   -- We clean all image data for a new run
   local function new_file(fname, ...)
      local f = io.open(fname, 'w')
      local a = {...}
      for _, v in pairs(a) do
	 f:write("# " .. v .. "\n")
      end
      f:close()
   end

   new_file("DNEB.results", "DNEB results file",
	    "Image reaction-coordinate Energy E-diff Curvature F-max(atom)")
   
   for img = 1, self.n_images do
      new_file( ("DNEB.%d.R"):format(img), "Coordinates")
      new_file( ("DNEB.%d.F"):format(img), "Constrained force")
      new_file( ("DNEB.%d.F.P"):format(img), "Perpendicular force")
      new_file( ("DNEB.%d.F.S.parallel"):format(img), "Spring parallel force")
      new_file( ("DNEB.%d.F.S.perpendicular"):format(img), "Spring perpendicular force")
      new_file( ("DNEB.%d.F.NEB"):format(img), "Resulting NEB force")
      new_file( ("DNEB.%d.T"):format(img), "NEB tangent")
      new_file( ("DNEB.%d.dR_prev"):format(img), "Reaction distance (previous)")
      new_file( ("DNEB.%d.dR_next"):format(img), "Reaction distance (next)")
   end

end

function DNEB:file_exists(name)--name
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

return DNEB
