--[[
Example on how to use an NEB method.
--]]

-- Load the FLOS module
local flos = require "flos"

local label = "siesta"

-- First we create the images
local images = {}

local n_images = 3

-- Function for reading a geometry
local read_geom = function(filename)
   local file = io.open(filename, "r")
   local na = tonumber(file:read())
   local R = flos.Array.zeros(na, 3)
   file:read()
   local i = 0
   local function tovector(s)
      local t = {}
      s:gsub('%S+', function(n) t[#t+1] = tonumber(n) end)
      return t
   end
   for i = 1, na do
      local line = file:read()
      if line == nil then break end
      -- Get stuff into the R
      local v = tovector(line)
      R[i][1] = v[1]
      R[i][2] = v[2]
      R[i][3] = v[3]
   end
   file:close()
   return R
end

-- Now read in the images (the below
for i = 0, n_images + 1 do
   images[#images+1] = flos.MDStep:new{R=read_geom("GEOMETRY_" .. i .. ".xyz")}
end

-- Now we have all images...
local NEB = flos.NEB:new(images)

local relax = {}
for i = 1, n_images do
   -- Select the relaxation method
   relax[i] = {}
   --relax[i][1] = flos.LBFGS:new({H0 = 1. / 75})
   relax[i][1] = flos.FIRE:new({dt_init = 1., direction="global", correct="global"})
   -- add more relaxation schemes if needed ;)
end

-- Counter for controlling which image we are currently relaxing
local current_image = 1

-- Grab the unit table of siesta (it is already created
-- by SIESTA)
local Unit = siesta.Units


function siesta_comm()
   
   -- This routine does exchange of data with SIESTA
   local ret_tbl = {}

   -- Do the actual communication with SIESTA
   if siesta.state == siesta.INITIALIZE then
      
      -- In the initialization step we request the
      -- convergence criteria
      --  MD.MaxDispl
      --  MD.MaxForceTol
      siesta_get({"Label",
		  "geom.xa",
		  "MD.MaxDispl",
		  "MD.MaxForceTol"})

      -- Store the Label
      label = tostring(siesta.Label)

      -- Print information
      IOprint("\nLUA NEB calculator")

      -- Ensure we update the convergence criteria
      -- from SIESTA (in this way one can ensure siesta options)
      for img = 1, n_images do
	 if siesta.IONode then
	    print(("\nLUA NEB relaxation method for image %d:"):format(img))
	 end
	 for i = 1, #relax[img] do
	    relax[img][i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
	    relax[img][i].max_dF = siesta.MD.MaxDispl / Unit.Ang
	    
	    -- Print information for this relaxation method
	    if siesta.IONode then
	       relax[img][i]:info()
	    end
	 end
      end

      -- This is only reached one time, and that it as the beginning...
      -- be sure to set the corresponding values
      siesta.geom.xa = NEB.initial.R * Unit.Ang

      -- force the initial image to be the first one to run
      current_image = 0

      ret_tbl = {'geom.xa'}

   end

   if siesta.state == siesta.MOVE then
      
      -- Here we are doing the actual LBFGS algorithm.
      -- We retrieve the current coordinates, the forces
      -- and whether the geometry has relaxed
      siesta_get({"geom.fa",
		  "E.total",
		  "MD.Relaxed"})

      -- Store the old image that has been tested,
      -- in this way we can check whether we have moved to
      -- a new image.
      local old_image = current_image
      
      ret_tbl = siesta_move(siesta)

      -- we need to re-organize the DM files for faster convergence
      -- pass whether the image is the same
      siesta_update_DM(old_image, current_image)

   end

   siesta_return(ret_tbl)
end

function siesta_move(siesta)

   -- Retrieve the atomic coordinates, forces and the energy
   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV
   local E = siesta.E.total / Unit.eV

   -- First update the coordinates, forces and energy for the current iteration
   NEB[current_image]:set{F=fa, E=E}

   if current_image == 0 then
      -- Perform the final image, to retain that information
      current_image = n_images + 1

      -- Set the atomic coordinates for the final image
      siesta.geom.xa = NEB[current_image].R * Unit.Ang

      IOprint("\nLUA/NEB final state\n")

      -- The siesta relaxation is already not set
      return {'geom.xa'}
      
   elseif current_image == n_images + 1 then

      -- Start the NEB calculation
      current_image = 1

      -- Set the atomic coordinates for the final image
      siesta.geom.xa = NEB[current_image].R * Unit.Ang

      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, n_images))
	 
      -- The siesta relaxation is already not set
      return {'geom.xa'}

   elseif current_image < n_images then

      -- step to next image
      current_image = current_image + 1

      -- Set the atomic coordinates for the image
      siesta.geom.xa = NEB[current_image].R * Unit.Ang

      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, n_images))

      -- The siesta relaxation is already not set
      return {'geom.xa'}

   end
   
   -- First we figure out how perform the NEB optimizations
   -- Now we have calculated all the systems and are ready for doing
   -- an NEB MD step

   -- Global variable to check for the NEB convergence
   -- Initially assume it has relaxed
   local relaxed = true

   -- loop on all images and pass the updated forces to the mixing algorithm
   for img = 1, n_images do

      -- Get the correct NEB force (note that the relaxation
      -- methods require the negative force)
      local F = NEB:force(img)

      -- Prepare the relaxation for image `img`
      local all_xa, weight, sum_w = {}, {}, 0.
      for i = 1, #relax[img] do
	 all_xa[i] = relax[img][i]:optimize(NEB[img].R, F)
	 weight[i] = relax[img][i].weight
	 sum_w = sum_w + weight[i]
      end

      -- Normalize according to the weighing scheme.
      -- We also print-out the weights for the algorithms
      -- if there are more than one of the LBFGS algorithms
      -- running simultaneously.
      local s = ""
      for i = 1, #relax[img] do
	 weight[i] = weight[i] / sum_w
	 s = s .. ", " .. string.format("%7.4f", weight[i])
      end
      if siesta.IONode and #relax[img] > 1 then
	 print("\n weighted average for relaxation: ", s:sub(3))
      end
      
      -- Calculate the new coordinates and figure out
      -- if the algorithms has been optimized.
      local out_xa = NEB[img].R * 0.
      for i = 1, #relax[img] do
	 out_xa = out_xa + all_xa[i] * weight[i]
	 relaxed = relaxed and relax[img][i].is_optimized
      end
      
      -- Copy the optimized coordinate back to the image
      NEB[img]:set{R=out_xa}

   end

   -- Start over in case the system has not relaxed
   current_image = 1
   if relaxed then
      -- the final coordinates are returned
      siesta.geom.xa = NEB.final.R * Unit.Ang
   else
      siesta.geom.xa = NEB[1].R * Unit.Ang
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, n_images))
   end

   -- Send back new coordinates (convert to Bohr)
   siesta.MD.Relaxed = relaxed
      
   return {"geom.xa",
	   "MD.Relaxed"}
end

function file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then
      io.close(f)
      return true
   else
      return false
   end
end

-- Function for retaining the DM files for the images so that we
-- can easily restart etc.
function siesta_update_DM(old, current)

   if not siesta.IONode then
      -- only allow the IOnode to perform stuff...
      return
   end

   -- Move about files so that we re-use old DM files
   local DM = label .. ".DM"
   local old_DM = DM .. "." .. tostring(old)
   local current_DM = DM .. "." .. tostring(current)

   if 1 <= old and old <= n_images and file_exists(DM) then
      -- store the current DM for restart purposes
      IOprint("Saving " .. DM .. " to " .. old_DM)
      os.execute("mv " .. DM .. " " .. old_DM)
   elseif file_exists(DM) then
      IOprint("Deleting " .. DM .. " for a clean restart...")
      os.execute("rm " .. DM)
   end

   if file_exists(current_DM) then
      IOprint("Restoring " .. current_DM .. " to " .. DM)
      os.execute("cp " .. current_DM .. " " .. DM)
   end

end
