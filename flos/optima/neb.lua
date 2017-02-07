--[[ 
This module implements the NEB algorithm.
--]]

local m = require "math"
local mc = require "flos.middleclass.middleclass"

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

   -- true/false for climbing image or not
   if climbing == nil then
      self.climbing = false
   else
      self.climbing = climbing
   end

   -- One should also attach the spring-constant
   -- It currently defaults to 5
   if base.istable(k) then
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
   
end

-- Simple wrapper for checking the image number
function NEB:_check_image(image)
   if image < 1 or self.n_images < image then
      error("NEB: requesting calculating the tanget of non-existing image!")
   end
end

-- Calculate the tangent of a give image (image as an integer, starting from 1)
function NEB:tangent(image)
   self:_check_image(image)
      

end


-- Get the actual force acting on image (image as an integer, starting from 1)
-- I.e. this is the force perpendicular to the tangent
function NEB:force(image)
   self:_check_image(image)

   -- Fake return to test
   return self[image].F

end


return NEB
