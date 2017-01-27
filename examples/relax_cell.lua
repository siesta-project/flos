--[[
Example on how to relax lattice vectors using the LBFGS 
algorithm.

This example can take any geometry and will relax the 
cell vectors according to the siesta input options:

 - MD.MaxStressTol
 - MD.MaxDispl

This example is prepared to easily create
a combined relaxation of several LBFGS algorithms
simultaneously. In some cases this is shown to
speed up the convergence because an average is taken
over several optimizations.

To converge using several LBFGS algorithms simultaneously
may be understood phenomenologically by a "line-search" 
optimization by weighing two Hessian optimizations.

This example defaults to two simultaneous LBFGS algorithms
which seems adequate in most situations.

--]]

-- Load the SFL module
local sfl = require "sfl"

-- Create the two LBFGS algorithms with
-- initial Hessians 1/75 and 1/50
local LBFGS = {}
LBFGS[1] = sfl.LBFGS:new({H0 = 1. / 75.})
LBFGS[2] = sfl.LBFGS:new({H0 = 1. / 50.})
-- To use more simultaneously simply add a
-- new line... with a separate LBFGS algorithm.

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
      --  MD.MaxStressTol
      siesta_get({"MD.MaxDispl",
		  "MD.MaxStressTol"})

      -- Print information
      if siesta.IONode then
	 -- empty line
	 print("\nLUA convergence information for the LBFGS algorithms:")
      end

      -- Ensure we update the convergence criteria
      -- from SIESTA (in this way one can ensure siesta options)
      for i = 1, #LBFGS do
	 LBFGS[i].tolerance = siesta.MD.MaxStressTol * Unit.Ang ^ 3 / Unit.eV
	 LBFGS[i].max_dF = siesta.MD.MaxDispl / Unit.Ang

	 -- Print information
	 if siesta.IONode then
	    LBFGS[i]:info()
	 end
      end

   end

   if siesta.state == siesta.MOVE then
      -- Here we are doing the actual LBFGS algorithm.
      -- We retrieve the current cell vectors, the stress
      -- the atomic coordinates (for rescaling)
      -- and whether the geometry has relaxed
      siesta_get({"geom.cell",
		  "geom.xa",
		  "geom.stress",
		  "MD.Relaxed"})
      ret_tbl = siesta_move(siesta)
   end

   siesta_return(ret_tbl)
end

function siesta_move(siesta)

   -- Retrieve the cell vectors
   local cell = sfl.Array2D.from(siesta.geom.cell) / Unit.Ang
   -- Retrieve the stress
   local tmp = sfl.Array2D.from(siesta.geom.stress) * Unit.Ang ^ 3 / Unit.eV
   local stress = sfl.Array2D:new(2, 3)
   
   -- Copy over the stress in the Voigt representation
   stress[1][1] = tmp[1][1]
   stress[1][2] = tmp[2][2]
   stress[1][3] = tmp[3][3]
   stress[2][1] = tmp[2][3]
   stress[2][2] = tmp[1][3]
   stress[2][3] = tmp[1][2]
   tmp = nil

   -- Perform step (initialize arrays to do averaging if more
   -- LBFGS algorithms are in use).
   local all_cell = {}
   local weight = {}
   local sum_w = 0.
   for i = 1, #LBFGS do
      
      -- Calculate the next optimized cell structure (that
      -- minimizes the Hessian)
      all_cell[i] = LBFGS[i]:optimize(cell, stress)
      
      -- Get the optimization length for calculating
      -- the best average.
      weight[i] = LBFGS[i].rho_optimized
      sum_w = sum_w + weight[i]
      
   end

   -- Normalize according to the weighing scheme.
   -- We also print-out the weights for the algorithms
   -- if there are more than one of the LBFGS algorithms
   -- running simultaneously.
   local s = ""
   for i = 1, #LBFGS do
      weight[i] = weight[i] / sum_w
      s = s .. ", " .. string.format("%7.4f", tostring(weight[i]))
   end
   if siesta.IONode and #LBFGS > 1 then
      print("\nLBFGS weighted average: ", s:sub(3))
   end

   -- Calculate the new coordinates and figure out
   -- if the algorithms has been optimized.
   local out_cell = cell * 0.
   local relaxed = true
   for i = 1, #LBFGS do
      out_cell = out_cell + all_cell[i] * weight[i]
      relaxed = relaxed and LBFGS[i].is_optimized
   end
   -- Immediately clean-up to reduce memory overhead (force GC)
   all_cell = nil


   -- Calculate the new scaled coordinates
   local lat = sfl.Lattice:new(cell)
   local fxa = lat:fractional(xa)
   -- Now convert to the new lattice
   xa = fxa:dot(out_cell)
   lat = nil
   fxa = nil
   
   -- Send back new coordinates (convert to Bohr)
   siesta.geom.cell = out_cell * Unit.Ang
   siesta.geom.xa = xa * Unit.Ang
   siesta.MD.Relaxed = relaxed
   
   return {"geom.cell",
	   "geom.xa",
	   "MD.Relaxed"}
end
