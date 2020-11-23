--[[
Example on how to converge the k-Mesh variable
in SIESTA.

This example can take any system and will
perform a series of calculations with increasing
Mesh.Cutoff.
Finally it will write-out a table file to be plotted
which contains the k-Mesh vs Energy. 

 - kgrid_Monkhorst_Pack

This example may be controlled via total 9 values. for each direction we'll have :

 1. kpoint_start_x
 2. kpoint_end_x
 3. kpoint_step_x

where then this script will automatically create 
an array of those values and iterate them.

--]]

local kpoint_start_x = 1.
local kpoint_end_x = 10.
local kpoint_step_x = 3.

local kpoint_start_y = 1.
local kpoint_end_y = 10
local kpoint_step_y = 3.

local kpoint_start_z = 1.
local kpoint_end_z = 1.
local kpoint_step_z = 1.

-- Load the FLOS module
local flos = require "flos"

-- Create array for each kpoints cutoffs
local kpoint_cutoff_x = flos.Array.range(kpoint_start_x, kpoint_end_x, kpoint_step_x)
local kpoint_cutoff_y = flos.Array.range(kpoint_start_y, kpoint_end_y, kpoint_step_y)
local kpoint_cutoff_z = flos.Array.range(kpoint_start_z, kpoint_end_z, kpoint_step_z)

local Total_kpoints = flos.Array.zeros(3)
Total_kpoints[1] = math.max(#kpoint_cutoff_x)
Total_kpoints[2] = math.max(#kpoint_cutoff_y)
Total_kpoints[3] = math.max(#kpoint_cutoff_z)
local kpoints_num =  Total_kpoints:max() 
local kpoint_mesh = flos.Array.zeros(9)
kpoint_mesh = kpoint_mesh:reshape(3,3)

local Etot = flos.Array.zeros(kpoints_num)
-- Initial cut-off element
local ikpoint_x = 1
local ikpoint_y = 1
local ikpoint_z = 1

local kpoints_num_temp = 0
function siesta_comm()
   
   -- Do the actual communication with SIESTA
   if siesta.state == siesta.INITIALIZE then
	       
      -- In the initialization step we request the
      -- Mesh cutoff (merely to be able to set it
      siesta.receive({"BZ.k.Matrix"})

     -- Overwrite to ensure we start from the beginning
     -- siesta.Mesh.Cutoff.Minimum = cutoff[icutoff]
     -- siesta.kpoint_scf%k_cell 

      kpoints = flos.Array.from(siesta.BZ.k.Matrix)
      --cell_first = flos.Array.from(siesta.geom.cell) / Unit.Ang

      --IOprint( ("\nLUA: starting mesh-cutoff: %8.3f Ry\n"):format(cutoff[icutoff]) )
      -- IOprint(kpoint_scf%k_cell)
      IOprint ("LUA: Provided k-point :" )--.. tostring( kpoints_num))
      
      kpoint_mesh = kpoints
      
      IOprint("LUA: k_x :\n" .. tostring(kpoint_cutoff_x))
      IOprint("LUA: k_y :\n" .. tostring(kpoint_cutoff_y))
      IOprint("LUA: k_z :\n" .. tostring(kpoint_cutoff_z))


      --siesta.send({"Mesh.Cutoff.Minimum"})
     
      IOprint("LUA: Total Number of k-points :" .. tostring(Total_kpoints:max() ))

      kpoint_mesh[1][1] = kpoint_start_x 
      kpoint_mesh[2][2] = kpoint_start_y
      kpoint_mesh[3][3] = kpoint_start_y

      IOprint ("LUA: Number of k-points (".. tostring(kpoints_num_temp+1) .. "/" .. tostring(Total_kpoints:max()).. ")" )
      IOprint("LUA: Starting Kpoint :\n" .. tostring(kpoint_mesh))
      siesta.BZ.k.Matrix = kpoint_mesh 
      siesta.send({"BZ.k.Matrix"})
   end

   if siesta.state == siesta.INIT_MD then
      
      siesta.receive({"BZ.k.Matrix"})
      -- Store the used meshcutoff for this iteration
      --cutoff[icutoff] = siesta.Mesh.Cutoff.Used
      --IOprint(siesta.BZ.k.Matrix)
   end

   if siesta.state == siesta.MOVE then

      -- Retrieve the total energy and update the
      -- meshcutoff for the next cycle
      -- Notice, we do not move, or change the geometry
      -- or cell-vectors.
      siesta.receive({"E.total",
		      "MD.Relaxed"})

      Etot[ikpoint_x ] = siesta.E.total
      
      -- Step the meshcutoff for the next iteration
      if step_kpointf_x(kpoint_cutoff_x[ikpoint_x]) then
	 kpoint_mesh[1][1] = kpoint_cutoff_x[ikpoint_x]
         if step_kpointf_y(kpoint_cutoff_y[ikpoint_y]) then
            kpoint_mesh[2][2] = kpoint_cutoff_y[ikpoint_y]
	    if step_kpointf_z(kpoint_cutoff_z[ikpoint_z]) then
	       kpoint_mesh[3][3] = kpoint_cutoff_z[ikpoint_z]
            end
          end
      end
	
	       --for i=1,3 do print(i) end	
         
	 --kpoint_mesh[1][1] = kpoint_cutoff_x[ikpoint_x]
	-- kpoint_mesh[2][2] = kpoint_cutoff_y[ikpoint_y]
         --kpoint_mesh[3][3] = kpoint_cutoff_z[ikpoint_z]
         
      --IOprint("Next Kpoint to Be Used : ".. tostring( ikpoint_x))
      --IOprint("kx :" .. tostring(kpoint_cutoff_x[ikpoint_x]))
      --IOprint("ky :" .. tostring(kpoint_cutoff_y[ikpoint_y]))
      --IOprint("kz :" .. tostring(kpoint_cutoff_z[ikpoint_z]))
       
      siesta.BZ.k.Matrix = kpoint_mesh

--      IOprint (siesta.BZ.k.Matrix)
	  --IOprint(tostring(step_kpointf[ikpoint]))
	  --siesta.BZ.k.Matrix = kpoint[ikpoint]
      --else
      --end
      --end
      --end
      kpoints_num_temp = kpoints_num_temp + 1
      --IOprint("Iterations : " .. tostring(kpoints_num_temp))
      
      if kpoints_num == kpoints_num_temp then
	 siesta.MD.Relaxed = true
      else
      --IOprint("Next Kpoint to Be Used :\n") --.. tostring( ikpoint_x))
      --IOprint("kx :" .. tostring(kpoint_cutoff_x[ikpoint_x]))
      --IOprint("ky :" .. tostring(kpoint_cutoff_y[ikpoint_y]))
      --IOprint("kz :" .. tostring(kpoint_cutoff_z[ikpoint_z]))
      --IOprint (siesta.BZ.k.Matrix)
      --IOprint("Iterations : " .. tostring(kpoints_num_temp))
      IOprint ("LUA: Number of k-points (".. tostring(kpoints_num_temp+1) .. "/" .. tostring(Total_kpoints:max()).. ")" )
      IOprint("LUA: Next Kpoint to Be Used :\n" .. tostring(siesta.BZ.k.Matrix))
      end
      
      siesta.send({"BZ.k.Matrix", "MD.Relaxed"})

   end

   if siesta.state == siesta.ANALYSIS then
      local file = io.open("k_meshcutoff_E.dat", "w")

      file:write("# kpoint-Mesh-cutoff vs. energy\n")

      -- We write out a table with mesh-cutoff, the difference between
      -- the last iteration, and the actual value
      --file:write( ("%8.3e  %17.10e  %17.10e\n"):format(kpoint_cutoff_x[1], Etot[1], 0.) )
      file:write( ("%8.3e %17.10e  %17.10e\n"):format(1, Etot[1], 0.) )
      
      --for i = 2, #kpoint_cutoff_x  do
      for i = 2, Total_kpoints:max()  do
	 --file:write( ("%8.3e %8.3e %8.3e %17.10e  %17.10e\n"):format(kpoint_cutoff_x[i],
	 file:write( ("%8.3e %17.10e  %17.10e\n"):format(i,Etot[i], Etot[i]-Etot[i-1]) )
      end

      file:close()

   end

end

-- Step the cutoff counter and return
-- true if successfull (i.e. if there are
-- any more to check left).
-- This function will also step past values 
function step_kpointf_x(cur_kpoint_x)

   if ikpoint_x < #kpoint_cutoff_x then
      ikpoint_x = ikpoint_x + 1
   else
      return false
   end

   if kpoint_cutoff_x[ikpoint_x] <= cur_kpoint_x then
      kpoint_cutoff_x[ikpoint_x] = kpoint_cutoff_x[ikpoint_x-1]
      Etot[ikpoint_x] = Etot[ikpoint_x-1]
      return step_kpointf_x(cur_kpoint_x)
   end

   return true
end

function step_kpointf_y(cur_kpoint_y)

   if ikpoint_y < #kpoint_cutoff_y then
      ikpoint_y = ikpoint_y + 1
   else
      return false
   end

   if kpoint_cutoff_y[ikpoint_y] <= cur_kpoint_y then
      kpoint_cutoff_y[ikpoint_y] = kpoint_cutoff_y[ikpoint_y-1]
      Etot[ikpoint_y] = Etot[ikpoint_y-1]
      return step_kpointf_y(cur_kpoint_y)
   end

   return true
end

function step_kpointf_z(cur_kpoint_z)

   if ikpoint_z < #kpoint_cutoff_z then
      ikpoint_z = ikpoint_z + 1
   else
      return false
   end

   if kpoint_cutoff_z[ikpoint_z] <= cur_kpoint_z then
      kpoint_cutoff_z[ikpoint_z] = kpoint_cutoff_x[ikpoint_z-1]
      Etot[ikpoint_z] = Etot[ikpoint_z-1]
      return step_kpointf_z(cur_kpoint_z)
   end

   return true
end

