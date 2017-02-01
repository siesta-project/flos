--[[
Example on how to converge the Mesh.Cutoff variable
in SIESTA.

This example can take any system and will
perform a series of calculations with increasing
Mesh.Cutoff.
Finally it will write-out a table file to be plotted
which contains the Mesh.Cutoff vs. 

 - MeshCutoff

This example may be controlled via 3 values:

 1. cutoff_start
 2. cutoff_end
 3. cutoff_step

where then this script will automatically create 
an array of those values and iterate them.
Note the values here are in Ry.

--]]

local cutoff_start = 150.
local cutoff_end = 650.
local cutoff_step = 50.

-- Load the FLOS module
local flos = require "flos"

-- Create array of cut-offs
local cutoff = flos.Array1D.range(cutoff_step, cutoff_end, cutoff_step)
local Etot = flos.Array1D.zeros(cutoff.size)
local icutoff = 1

-- Grab the unit table of siesta (it is already created by SIESTA)
local Unit = siesta.Units

function siesta_comm()
   
   -- This routine does exchange of data with SIESTA
   local ret_tbl = {}

   -- Do the actual communication with SIESTA
   if siesta.state == siesta.INITIALIZE then
      
      -- In the initialization step we request the
      -- Mesh cutoff (merely to be able to set it
      siesta_get({"Mesh.Cutoff.Minimum"})

      -- Overwrite to ensure we start from the beginning
      siesta.Mesh.Cutoff.Minimum = cutoff[icutoff]

      if siesta.IONode then
	 print( ("\nLUA: starting mesh-cutoff: %8.3f Ry\n"):format(cutoff[icutoff]) )
      end

      ret_tbl = {"Mesh.Cutoff.Minimum"}

   end

   if siesta.state == siesta.INIT_MD then

      siesta_get({"Mesh.Cutoff.Used"})
      -- Store the used meshcutoff for this iteration
      cutoff[icutoff] = siesta.Mesh.Cutoff.Used

   end

   if siesta.state == siesta.MOVE then

      -- Retrieve the total energy and update the
      -- meshcutoff for the next cycle
      -- Notice, we do not move, or change the geometry
      -- or cell-vectors.
      siesta_get({"E.total",
		  "MD.Relaxed"})

      Etot[icutoff] = siesta.E.total
      
      -- Step the meshcutoff for the next iteration
      if step_cutoff(cutoff[icutoff]) then
	 siesta.Mesh.Cutoff.Minimum = cutoff[icutoff]
      else
	 siesta.MD.Relaxed = true
      end
      
      ret_tbl = {"Mesh.Cutoff.Minimum", "MD.Relaxed"}

   end

   if siesta.state == siesta.ANALYSIS then
      -- Here we simply write the obtained data

      local file = io.open("MeshvsE.dat", "w")

      file:write("# Mesh-cutoff vs. energy\n")

      -- We write out a table with mesh-cutoff, the difference between
      -- the last iteration, and the actual value
      file:write( ("%8.3e  %17.10e  %17.10e\n"):format(cutoff[1], 0., Etot[1]) )
      for i = 2, #cutoff do
	 file:write( ("%8.3e  %17.10e  %17.10e\n"):format(cutoff[i], Etot[i]-Etot[i-1], Etot[i]) )
      end

      file:close()

   end

   siesta_return(ret_tbl)
end

-- Step the cutoff counter and return
-- true if successfull (i.e. if there are
-- any more to check left).
-- This function will also step past values 
function step_cutoff(cur_cutoff)

   if icutoff < #cutoff then
      icutoff = icutoff + 1
   else
      return false
   end

   if cutoff[icutoff] <= cur_cutoff then
      cutoff[icutoff] = cutoff[icutoff-1]
      Etot[icutoff] = Etot[icutoff-1]
      return step_cutoff(cur_cutoff)
   end

   return true
end
