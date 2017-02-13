--[[ 
This module implements the NEB algorithm.
--]]

local m = require "math"
local mc = require "flos.middleclass.middleclass"

local array = require "flos.num"
local ferror = require "flos.error"
local error = ferror.floserr
local optim = require "flos.optima.base"

-- Create the NEB class (inheriting the Optimizer construct)
local NEB = mc.class("NEB", optim.Optimizer)

function NEB:initialize(images, climbing, k)

   -- Copy all images over
   local size_img = #images[1].R
   for i = 1, #images do
      self[i-1] = images[i]
      if #images[i].R ~= size_img then
	 error("NEB: images does not have same size of geometries!")
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
   local cl = climbing or 5
   if cl == false then
      self._climbing = 1000000000000
   else
      -- Counter for climbing
      self._climbing = cl
   end

   self.niter = 0

   -- One should also attach the spring-constant
   -- It currently defaults to 5
   if type(k) == "table" then
      self.k = k
   else
      local nk = 5.
      if k ~= nil then
	 nk = k
      end
      self.k = setmetatable({},
			    {
			       __index = function(t, k)
				  return nk
			       end
			    })
   end

   self:init_files()

end

-- Simple wrapper for checking the image number
function NEB:_check_image(image)
   if image < 1 or self.n_images < image then
      error("NEB: requesting a non-existing image!")
   end
end


-- Return the coordinate difference between two images
function NEB:dR(img1, img2)
   -- This function assumes the reference
   -- image is checked in the parent function

   return self[img2].R - self[img1].R

end

-- Calculate the tangent of a give image (image as an integer, starting from 1)
function NEB:tangent(image)
   self:_check_image(image)

   -- Determine energies of relevant images
   local E_prev = self[image-1].E
   local E_this = self[image].E
   local E_next = self[image+1].E

   -- Determine position differences
   local dR_plus  = self:dR(image, image+1)
   local dR_minus = self:dR(image-1, image)

   -- Returned value
   local tangent

   -- Determine relevant energy scenario
   if E_next > E_this and E_this > E_prev then
      
      tangent = dR_plus

   elseif E_next < E_this and E_this < E_prev then
      
      tangent = dR_minus

   else
      
      -- We are at extremum, so mix
      local dEmax = m.max( m.abs(E_next - E_this), m.abs(E_prev - E_this) )
      local dEmin = m.min( m.abs(E_next - E_this), m.abs(E_prev - E_this) )
      
      if E_next > E_prev then
	 tangent = dR_plus * dEmax + dR_minus * dEmin
      else
	 tangent = dR_plus * dEmin + dR_minus * dEmax
      end
      
   end

   -- At this point we have a tangent,
   -- now normalize and return it
   return tangent / tangent:norm(0)

end


-- Determine if a given image is an extremum and if we should use climbing image
function NEB:climbing(image)
   self:_check_image(image)
   
   -- Determine energies of relevant images
   local E_prev = self[image-1].E
   local E_this = self[image  ].E
   local E_next = self[image+1].E
   
   -- Return boolean value depending on energies
   return (E_this > E_prev and E_this > E_next) or (E_this < E_prev and E_this < E_next)

end

-- Determine spring force on image (image as an integer, starting from 1)
function NEB:spring_force(image)
   self:_check_image(image)
   
   -- Determine position norms
   local dR_plus  = self:dR(image, image+1):norm(0)
   local dR_minus = self:dR(image-1, image):norm(0)
   
   -- Set spring force as F = k (R1-R2) * tangent
   return self.k[image] * (dR_plus - dR_minus) * self:tangent(image)
   
end


-- Determine perpendicular force on image (image as an integer, starting from 1)
function NEB:perpendicular_force(image)
   self:_check_image(image)

   -- Subtract the force projected onto the tangent to get the perpendicular force
   local P = self[image].F:project(self:tangent(image))
   return self[image].F - P

end

-- Determine image curvature (image as an integer, starting from 1)
function NEB:curvature(image)
   self:_check_image(image)

   local tangent = self:tangent(image)

   -- Return the scalar projection of F onto the tangent (in this case the
   -- tangent is already normalized so no need to no a normalization)
   return self[image].F:flatdot(tangent)
   
end

function NEB:neb_force(image)
   self:_check_image(image)

   local NEB_F

   -- Only run Climbing image after a certain amount of steps (robustness)
   -- Typically this number is 5.
   if self.niter > self._climbing and self:climbing(image) then
      local F = self[image].F
      local tangent = self:tangent(image)
      NEB_F = F - 2 * F:project(tangent)
   else
      local perp_F = self:perpendicular_force(image)
      local spring_F = self:spring_force(image)
      NEB_F = perp_F + spring_F
   end

   return NEB_F

end

-- Get the actual force acting on image (image as an integer, starting from 1)
-- I.e. this is the force perpendicular to the tangent
function NEB:force(image, IO)
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
      f = io.open( ("NEB.%d.R"):format(image), "a")
      self[image].R:savetxt(f)
      f:close()

      -- Forces before (ie .F)
      f = io.open( ("NEB.%d.F"):format(image), "a")
      F:savetxt(f)
      f:close()

      -- Perpendicular force
      f = io.open( ("NEB.%d.F.P"):format(image), "a")
      perp_F:savetxt(f)
      f:close()
      
      -- Spring force
      f = io.open( ("NEB.%d.F.S"):format(image), "a")
      spring_F:savetxt(f)
      f:close()

      -- NEB Force
      f = io.open( ("NEB.%d.F.NEB"):format(image), "a")
      NEB_F:savetxt(f)
      f:close()

      -- Tangent
      f = io.open( ("NEB.%d.T"):format(image), "a")
      tangent:savetxt(f)
      f:close()

      -- dR - previous reaction coordinate
      f = io.open( ("NEB.%d.dR_prev"):format(image), "a")
      self:dR(image-1, image):savetxt(f)
      f:close()

      -- dR - next reaction coordinate
      f = io.open( ("NEB.%d.dR_next"):format(image), "a")
      self:dR(image, image+1):savetxt(f)
      f:close()

   end

   -- Fake return to test
   return NEB_F
   
end

--- Store the current step of the NEB iteration with the appropriate results
function NEB:save(IO)

   -- If we should not do IO, return immediately
   if not IO then
      return
   end

   -- Now setup the matrix to write the NEB-results
   local dat = array.Array( self.n_images + 2, 6)
   for i = 0, self.n_images + 1 do

      local row = dat[i+1]
      -- image number (0 for initial, n_images + 1 for final)
      row[1] = i
      -- Reaction coordinate
      if i == 0 then
	 row[2] = 0.
      else
	 row[2] = self:dR(i-1, i):norm(0)
      end
      -- Total energy of current iteration
      row[3] = self[i].E
      -- Energy difference from previous reaction coordinate
      if i == 0 then
	 row[4] = 0.
      else
	 row[4] = self[i].E - self[i-1].E
      end
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

   local f = io.open("NEB.results", "a")
   dat:savetxt(f)
   f:close()

end

function NEB:init_files()
   
   -- We clean all image data for a new run
   local function new_file(fname, ...)
      local f = io.open(fname, 'w')
      local a = {...}
      for _, v in pairs(a) do
	 f:write("# " .. v .. "\n")
      end
      f:close()
   end

   new_file("NEB.results", "NEB results file",
	    "Image reaction-coordinate Energy E-diff Curvature F-max(atom)")
   
   for img = 1, self.n_images do
      new_file( ("NEB.%d.R"):format(img), "Coordinates")
      new_file( ("NEB.%d.F"):format(img), "Constrained force")
      new_file( ("NEB.%d.F.P"):format(img), "Perpendicular force")
      new_file( ("NEB.%d.F.S"):format(img), "Spring force")
      new_file( ("NEB.%d.F.NEB"):format(img), "Resulting NEB force")
      new_file( ("NEB.%d.T"):format(img), "NEB tangent")
      new_file( ("NEB.%d.dR_prev"):format(img), "Reaction distance (previous)")
      new_file( ("NEB.%d.dR_next"):format(img), "Reaction distance (next)")
   end

end

return NEB
