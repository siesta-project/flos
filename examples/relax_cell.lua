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

-- Load the FLOS module
local flos = require "flos"

-- Create the two LBFGS algorithms with
-- initial Hessians 1/75 and 1/50
local LBFGS = {}
LBFGS[1] = flos.LBFGS:new({H0 = 1. / 75.})
LBFGS[2] = flos.LBFGS:new({H0 = 1. / 50.})
-- To use more simultaneously simply add a
-- new line... with a separate LBFGS algorithm.

-- Grab the unit table of siesta (it is already created
-- by SIESTA)
local Unit = siesta.Units

-- Initial strain that we want to optimize to minimize
-- the stress.
local strain = flos.Array2D.zeros(2, 3)
-- Mask which directions we should relax
--   [[xx, yy, zz],
--    [yz, xz, xy]]
-- Default to all.
local stress_mask = flos.Array2D.ones(2, 3)
-- In this example we only converge the
-- diagonal stress
stress_mask[2] = stress_mask[2] * 0.

-- The initial cell
local cell_first

function siesta_comm()
   
   -- This routine does exchange of data with SIESTA
   local ret_tbl = {}

   -- Do the actual communication with SIESTA
   if siesta.state == siesta.INITIALIZE then
      
      -- In the initialization step we request the
      -- convergence criteria
      --  MD.MaxDispl
      --  MD.MaxStressTol
      siesta_get({"geom.cell",
		  "MD.Relax.Cell",
		  "MD.MaxDispl",
		  "MD.MaxStressTol"})

      -- Check that we are allowed to change the cell parameters
      if not siesta.MD.Relax.Cell then

	 -- We force SIESTA to relax the cell vectors
	 siesta.MD.Relax.Cell = true
	 ret_tbl = {"MD.Relax.Cell"}

      end

      -- Print information
      if siesta.IONode then
	 -- empty line
	 print("\nLUA convergence information for the LBFGS algorithms:")
      end

      -- Store the initial cell (global variable)
      cell_first = flos.Array2D.from(siesta.geom.cell) / Unit.Ang

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

   -- Get the current cell
   local cell = flos.Array2D.from(siesta.geom.cell) / Unit.Ang
   -- Retrieve the atomic coordinates
   local xa = flos.Array2D.from(siesta.geom.xa) / Unit.Ang
   -- Retrieve the stress
   local tmp = flos.Array2D.from(siesta.geom.stress) * Unit.Ang ^ 3 / Unit.eV
   local stress = flos.Array2D:new(2, 3)

   -- Copy over the stress to the Voigt representation
   stress[1][1] = tmp[1][1]
   stress[1][2] = tmp[2][2]
   stress[1][3] = tmp[3][3]
   -- ... symmetrize stress tensor
   stress[2][1] = (tmp[2][3] + tmp[3][2]) * 0.5
   stress[2][2] = (tmp[1][3] + tmp[3][1]) * 0.5
   stress[2][3] = (tmp[1][2] + tmp[2][1]) * 0.5
   tmp = nil

   -- Apply stress-mask to the current stress
   stress = stress * stress_mask
   -- Calculate the volume of the cell to normalize the stress
   local vol = cell[1]:cross(cell[2]):dot(cell[3])
   
   -- Perform step (initialize arrays to do averaging if more
   -- LBFGS algorithms are in use).
   local all_strain = {}
   local weight = {}
   local sum_w = 0.
   for i = 1, #LBFGS do
      
      -- Calculate the next optimized cell structure (that
      -- minimizes the Hessian)
      -- The optimization routine requires the stress to be per cell
      all_strain[i] = LBFGS[i]:optimize(strain, stress * vol)

      -- The LBFGS algorithms updates the is_optimized
      -- variable based on stress * vol (eV / cell)
      -- However, we are relaxing the stress in (eV / Ang^3)
      -- So force the optimization to be estimated on the
      -- correct units.
      -- Secondly, the stress optimization is per element
      -- so we need to flatten the stress
      LBFGS[i]:optimized(stress:reshape(-1))
      
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

   -- Calculate the new optimized strain that should
   -- be applied to the cell vectors to minimize the stress.
   -- Also track if we have converged (stress < min-stress)
   local out_strain = strain * 0.
   local relaxed = true
   for i = 1, #LBFGS do
      out_strain = out_strain + all_strain[i] * weight[i]
      relaxed = relaxed and LBFGS[i].is_optimized
   end
   -- Immediately clean-up to reduce memory overhead (force GC)
   all_strain = nil

   -- Apply mask to ensure only relaxation of cell-vectors
   -- along wanted directions.
   strain = out_strain * stress_mask
   out_strain = nil

   -- Calculate the new cell
   -- Note that we add one in the diagonal
   -- to create the summed cell
   local dcell = cell * 0.
   dcell[1][1] = 1.0 + strain[1][1]
   dcell[1][2] = 0.5 * strain[2][3]
   dcell[1][3] = 0.5 * strain[2][2]
   dcell[2][1] = 0.5 * strain[2][3]
   dcell[2][2] = 1.0 + strain[1][2]
   dcell[2][3] = 0.5 * strain[2][1]
   dcell[3][1] = 0.5 * strain[2][2]
   dcell[3][2] = 0.5 * strain[2][1]
   dcell[3][3] = 1.0 + strain[1][3]

   -- Create the new cell...
   -- As the strain is a continuously updated value
   -- we need to retain the original cell (done
   -- above in the siesta.INITIALIZE step).
   local out_cell = cell_first:dot(dcell)
   dcell = nil
   
   -- Calculate the new scaled coordinates
   -- First get the fractional coordinates in the
   -- previous cell.
   local lat = flos.Lattice:new(cell)
   local fxa = lat:fractional(xa)
   -- Then convert the coordinates to the
   -- new cell coordinates by simple scaling.
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
