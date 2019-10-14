--[[
Example on how to use an NEB method.
--]]
-- Load the FLOS module
local flos = require "flos"
-- The prefix of the files that contain the images
local image_label = "image_coordinates_"
local image_vector_label= "image_vectors_"
-- Total number of images (excluding initial[0] and final[n_images+1])
local n_images = 5
-- Table of image geometries
local images = {}
local images_vectors={}
-- The default output label of the DM files
local label = "MgO-3x3x1-2V"
local f_label_xyz = "image_coordinates_"
local f_label_xyz_vec = "image_vectors_"
-- Function for reading a geometry of vector
local read_geom_vec = function(filename)
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
-- Now read in the images
for i = 0, n_images + 1 do
   images[#images+1] = flos.MDStep{R=read_geom(image_label .. i .. ".xyz")}
   images_vectors[#images_vectors+1]= flos.MDStep{R=read_geom_vec(image_vector_label .. i .. ".xyz")}
end
-- Now we have all images...
local NEB = flos.VCNEB(images)
local VCNEB = flos.VCNEB(images_vectors)
NEB.DM_label=labe --"MgO-3x3x1-2V"
if siesta.IONode then
   NEB:info()
   VCNEB:info()
end
-- Remove global (we use NEB.n_images)
n_images = nil
-- Setup each image relaxation method (note it is prepared for several
-- relaxation methods per-image)
local relax = {}
local vcrelax= {}
for i=1, NEB.n_images do
   relax[i]={}
   vcrelax[i]={}
   relax[i][1] = flos.CG{beta='PR', line=flos.Line{optimizer = flos.LBFGS{H0 = 1. / 25.} } }
   vcrelax[i][1] = flos.CG{beta='PR', line=flos.Line{optimizer = flos.LBFGS{H0 = 1. / 75.} } }
   if siesta.IONode then
      NEB:info()
      VCNEB:info()
    end
   --relax[i][2] = flos.LBFGS{H0 = 1. / 50}
   --relax[i][1] = flos.FIRE{dt_init = 1., direction="global", correct="global"}
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
      siesta.receive({"Label",
		      "geom.xa",
		      "MD.MaxDispl",
		      "MD.MaxForceTol",
          "MD.MaxStressTol",
          "geom.cell",
          "geom.stress"})
      -- Store the Label
      label = tostring(siesta.Label)
      --stress=flos.Array.from(siesta.geom.stress)* Unit.Ang ^ 3 / Unit.eV
      -- Print information
      IOprint("\nLUA NEB calculator")
      -- Ensure we update the convergence criteria
      -- from SIESTA (in this way one can ensure siesta options)
      for img = 1, NEB.n_images do
	 IOprint(("\nLUA NEB relaxation method for image %d:"):format(img))
	 for i = 1, #relax[img] do
	    relax[img][i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
	    relax[img][i].max_dF = siesta.MD.MaxDispl / Unit.Ang
	    vcrelax[img][i].tolerance = siesta.MD.MaxStressTol * Unit.Ang ^ 3 / Unit.eV
	    vcrelax[img][i].max_dF = siesta.MD.MaxDispl / Unit.Ang	    
	    -- Print information for this relaxation method
	    if siesta.IONode then
	       relax[img][i]:info()
         vcrelax[img][i]:info()
	    end
	 end
      end
      -- This is only reached one time, and that it as the beginning...
      -- be sure to set the corresponding values
      siesta.geom.xa = NEB.initial.R * Unit.Ang
      siesta.geom.cell = VCNEB.initial.R * Unit.Ang
      IOprint("\nLUA/NEB initial state\n")
      -- force the initial image to be the first one to run
      --IOprint(VCNEB.zeros)
      current_image = 0
      siesta_update_DM(0, current_image)
      --Write xyz File
      siesta_update_xyz(current_image)
      siesta_update_xyz_vec(current_image)
      IOprint("============================================")
      IOprint("Lattice Vector")
      IOprint(VCNEB[current_image].R)
      IOprint("============================================")
      IOprint("Atomic Coordinates")
      IOprint(NEB[current_image].R)
      IOprint("============================================")
      ret_tbl = {'geom.xa',"geom.stress","geom.cell"}
   end
   if siesta.state == siesta.MOVE then      
      -- Here we are doing the actual LBFGS algorithm.
      -- We retrieve the current coordinates, the forces
      -- and whether the geometry has relaxed
      siesta.receive({"geom.fa",
		      "E.total",
		      "MD.Relaxed",
          "geom.cell",
          "geom.stress"})
      -- Store the old image that has been tested,
      -- in this way we can check whether we have moved to
      -- a new image.
      local old_image = current_image  
      ret_tbl = siesta_move(siesta)
      -- we need to re-organize the DM files for faster convergence
      -- pass whether the image is the same
      --stress=flos.Array.from(siesta.geom.stress)* Unit.Ang ^ 3 / Unit.eV
      siesta_update_DM(old_image, current_image)
      siesta_update_xyz(current_image)
      siesta_update_xyz_vec(current_image)
      --IOprint(stress)
   end
   siesta.send(ret_tbl)
end
function siesta_move(siesta)
   -- Retrieve the atomic coordinates, forces and the energy
   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV
   local E = siesta.E.total / Unit.eV
   -- First update the coordinates, forces and energy for the
   -- just calculated image
   --print(fa)
   NEB[current_image]:set{F=fa, E=E}
 --[[ Retrieve the vector coordinates, forces and the energy   --]]
   --local cell=flos.Array.from(siesta.geom.cell)/ Unit.Ang
   --local vol=cell[1]:cross(cell[2]):dot(cell[3])
   local Vfa = (-flos.Array.from(siesta.geom.stress) * Unit.Ang ^ 3 / Unit.eV)--* vol
   local VE = siesta.E.total / Unit.eV
   -- First update the coordinates, forces and energy for the
   -- just calculated image
   --print(Vfa)
   VCNEB[current_image]:set{F=Vfa,E=VE}
   --VCNEB:force(current_image, siesta.IONode)
   if current_image == 0 then
      -- Perform the final image, to retain that information
      current_image = NEB.n_images + 1
      -- Set the atomic coordinates for the final image
      siesta.geom.xa = NEB[current_image].R * Unit.Ang
      siesta.geom.cell = VCNEB[current_image].R * Unit.Ang
      IOprint("\nLUA/NEB final state\n")
      IOprint("Lattice Vectors")
      IOprint(VCNEB[current_image].R)
      IOprint("Stresss")
      IOprint(VCNEB[current_image].F)
      --IOprint(stress)
      -- The siesta relaxation is already not set
      return {'geom.xa',"geom.stress","geom.cell"}    
   elseif current_image == NEB.n_images + 1 then
      -- Start the NEB calculation
      current_image = 1
      -- Set the atomic coordinates for the final image
      siesta.geom.xa = NEB[current_image].R * Unit.Ang
      siesta.geom.cell = VCNEB[current_image].R * Unit.Ang
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, NEB.n_images))
      IOprint("Lattice Vectors")
      IOprint(VCNEB[current_image].R)
      IOprint("Stresss")
      IOprint(VCNEB[current_image].F)
      -- The siesta relaxation is already not set
      return {'geom.xa',"geom.stress","geom.cell"}
   elseif current_image < NEB.n_images then
      current_image = current_image + 1
      -- Set the atomic coordinates for the image
      siesta.geom.xa = NEB[current_image].R * Unit.Ang
      siesta.geom.cell = VCNEB[current_image].R * Unit.Ang
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, NEB.n_images))
      IOprint("Lattice Vectors")
      IOprint(VCNEB[current_image].R)
      IOprint("Stresss")
      IOprint(VCNEB[current_image].F)
      --IOprint(NEB.tangent)
      -- The siesta relaxation is already not set
      return {'geom.xa',"geom.stress","geom.cell"}
   end   
   -- First we figure out how perform the NEB optimizations
   -- Now we have calculated all the systems and are ready for doing
   -- an NEB MD step
   -- Global variable to check for the NEB convergence
   -- Initially assume it has relaxed
   local relaxed = true
   local vcrelaxed = true
   local tot_relax= false
   IOprint("\nNEB step")
   local out_R = {}
   local out_VR = {}
   -- loop on all images and pass the updated forces to the mixing algorithm
   for img = 1, NEB.n_images do
      -- Get the correct NEB force (note that the relaxation
      -- methods require the negative force)
      local F = NEB:force(img, siesta.IONode)
      IOprint("NEB: max F on image ".. img ..
		 (" = %10.5f, climbing = %s"):format(F:norm():max(),
						     tostring(NEB:climbing(img))) )
     -- Prepare the relaxation for image `img`
      local all_xa, weight = {}, flos.Array( #relax[img] )      
      for i = 1, #relax[img] do
	 all_xa[i] = relax[img][i]:optimize(NEB[img].R, F)
	 weight[i] = relax[img][i].weight
      end
      weight = weight / weight:sum()
      if #relax[img] > 1 then
	 IOprint("\n weighted average for relaxation: ", tostring(weight))
      end
      -- Calculate the new coordinates and figure out
      -- if the algorithm has converged (all forces below)
      local out_xa = all_xa[1] * weight[1]
      relaxed = relaxed and relax[img][1]:optimized()
      for i = 2, #relax[img] do
	 out_xa = out_xa + all_xa[i] * weight[i]
	 relaxed = relaxed and relax[img][i]:optimized()
      end
      -- Copy the optimized coordinates to a table
      --out_R[img] = out_xa
      --================================================================-
      -- For Lattice Optimization
      --================================================================-
      local icell = VCNEB[img].R --/ Unit.Ang
      --local all_strain={}
      local ivol=icell[1]:cross(icell[2]):dot(icell[3])
      local strain=flos.Array.zeros(6)
      local stress_mask=flos.Array.ones(6)
      stress_mask[3]=0.0
      stress_mask[4]=0.0  
      stress_mask[5]=0.0
      stress_mask[6]=0.0
      local stress=-stress_to_voigt(siesta.geom.stress)--* Unit.Ang ^ 3 / Unit.eV
      stress = stress * stress_mask
      local VF = VCNEB:force(img, siesta.IONode)
     IOprint("VCNEB: max Strain F on image ".. img ..
		 (" = %10.5f, climbing = %s"):format(VF:norm():max(),
      			     tostring(VCNEB:climbing(img))) )
     IOprint(VCNEB[img].F)        
      local all_vcxa, vcweight = {}, flos.Array( #vcrelax[img] )
      for i = 1, #vcrelax[img] do
	 all_vcxa[i] = vcrelax[img][i]:optimize(strain, stress )--* ivol
	 vcweight[i] = vcrelax[img][i].weight
      end
      vcweight = vcweight / vcweight:sum()
            if #vcrelax[img] > 1 then
	 IOprint("\n weighted average for cell relaxation: ", tostring(vcweight))
      end
      -- Calculate the new coordinates and figure out
      -- if the algorithm has converged (all forces below)
      local out_vcxa = all_vcxa[1] * vcweight[1]
      vcrelaxed = vcrelaxed and vcrelax[img][1]:optimized()
      for i = 2, #relax[img] do
	 out_vcxa = out_vcxa + all_vcxa[i] * vcweight[i]
	 vcrelaxed = vcrelaxed and vcrelax[img][i]:optimized()
      end
    
    --local out_strain=all_strain[1]*vcweight[1]
    all_vcxa = nil   --all_strain = nil
    strain = out_vcxa * stress_mask  --strain = out_strain * stress_mask
    out_vcxa = nil --strain = out_strain * stress_mask --out_strain = nil
    local dcell = flos.Array(icell.shape)
    dcell[1][1]=1.0 + strain[1]
    dcell[1][2]=0.5 * strain[6]
    dcell[1][3]=0.5 * strain[5]
    dcell[2][1]=0.5 * strain[6]
    dcell[2][2]=1.0 + strain[2]
    --dcell[2][2]=1.0 + strain[1]
    dcell[2][3]=0.5 * strain[4]
    dcell[3][1]=0.5 * strain[5]
    dcell[3][2]=0.5 * strain[4]
    dcell[3][3]=1.0 + strain[3]
    local out_cell=icell:dot(dcell)
    --local out_cell=icell+dcell
    --print ("stress")
    --print(stress)
    --print("cell out")
    --print (out_cell)
    dcell = nil
    local lat = flos.Lattice:new(icell)
    local fxa = lat:fractional(out_xa)
    xa =fxa:dot(out_cell)
    lat = nil
    fxa = nil
      -- Copy the optimized vectors to a table
    out_VR[img] = out_cell
    -- Copy the optimized coordinates with respecto to new optimized vectors to a table
    out_R[img] = xa
      --================================================================--
   end

   -- Before we update the coordinates we will write
   -- the current steps results to the result file
   -- (this HAS to be done before updating the coordinates)
   NEB:save( siesta.IONode )

   -- Now we may copy over the coordinates (otherwise
   -- we do a consecutive update, and then overwrite)
   for img = 1, NEB.n_images do
      NEB[img]:set{R=out_R[img]}
      VCNEB[img]:set{R=out_VR[img]}
   end   
   -- Start over in case the system has not relaxed
   current_image = 1
   if relaxed and vcrelaxed then
     tot_relax= true
      -- the final coordinates are returned
      siesta.geom.xa = NEB.final.R * Unit.Ang
      siesta.geom.cell = VCNEB.final.R * Unit.Ang 
      IOprint("\nLUA/NEB complete\n")
   else
      siesta.geom.xa = NEB[1].R * Unit.Ang
      siesta.geom.cell = VCNEB[1].R * Unit.Ang 
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, NEB.n_images))
      IOprint("Lattice Vectors")
      IOprint(VCNEB[1].R)
      IOprint("Stresss")
      IOprint(VCNEB[1].F)
   end
   siesta.MD.Relaxed = tot_relax      
   return {"geom.xa","geom.stress","geom.cell",
	   "MD.Relaxed"}
end
--[[
function file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then
      io.close(f)
      return true
   else
      return false
   end
end--]]

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
   local initial_DM = DM .. ".0"
   local final_DM = DM .. ".".. tostring(NEB.n_images+1) 
   print ("The Label of Old DM is : " .. old_DM)
   print ("The Label of Current DM is : " .. current_DM)
   -- Saving initial DM
   if old==0 and current==0 then
     print("Removing DM for Resuming")
     IOprint("Deleting " .. DM .. " for a clean restart...")
     os.execute("rm " .. DM)
   end 
  
   if 0 <= old and old <= NEB.n_images+1 and NEB:file_exists(DM) then
      -- store the current DM for restart purposes
      IOprint("Saving " .. DM .. " to " .. old_DM)
      os.execute("mv " .. DM .. " " .. old_DM)
   elseif NEB:file_exists(DM) then
      IOprint("Deleting " .. DM .. " for a clean restart...")
      os.execute("rm " .. DM)
   end

   if NEB:file_exists(current_DM) then
      IOprint("Deleting " .. DM .. " for a clean restart...")
      os.execute("rm " .. DM)
      IOprint("Restoring " .. current_DM .. " to " .. DM)
      os.execute("cp " .. current_DM .. " " .. DM)
   end

end

function stress_to_voigt(stress)
   local voigt = flos.Array.empty(6)
   voigt[1]=stress[1][1]
   voigt[2]=stress[2][2]
   voigt[3]=stress[3][3]
   voigt[4]=(stress[2][3]+stress[3][2])*0.5
   voigt[5]=(stress[1][3]+stress[3][1])*0.5
   voigt[6]=(stress[1][2]+stress[2][1])*0.5
   return voigt
end
function siesta_update_xyz(current)
  if not siesta.IONode then
      -- only allow the IOnode to perform stuff...
      return
   end
  local xyz_label = f_label_xyz ..tostring(current)..".xyz"
  --self:_n_images=self.n_images
  --self:_check_image(image)
    
  local f=io.open(xyz_label,"w")
  f:write(tostring(#NEB[current].R).."\n \n")
  --f:write(tostring(initialize:self.n_images).."\n \n")
  for i=1,#NEB[current].R do
    f:write(string.format(" %19.17f",tostring(NEB[current].R[i][1])).. "   "..string.format("%19.17f",tostring(NEB[current].R[i][2]))..string.format("   %19.17f",tostring(NEB[current].R[i][3])).."\n")
 end
 f:close()
  --  
end

function siesta_update_xyz_vec(current)
  if not siesta.IONode then
      -- only allow the IOnode to perform stuff...
      return
   end
  local xyz_vec_label = f_label_xyz_vec ..tostring(current)..".xyz"
  --self:_n_images=self.n_images
  --self:_check_image(image)
    
  local f=io.open(xyz_vec_label,"w")
  f:write(tostring(#VCNEB[current].R).."\n \n")
  --f:write(tostring(initialize:self.n_images).."\n \n")
  for i=1,#VCNEB[current].R do
    f:write(string.format(" %19.17f",tostring(VCNEB[current].R[i][1])).. "   "..string.format("%19.17f",tostring(VCNEB[current].R[i][2]))..string.format("   %19.17f",tostring(VCNEB[current].R[i][3])).."\n")
 end
 f:close()
  --  
end