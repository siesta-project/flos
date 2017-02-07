--[[
Example on how to relax a geometry using the FIRE
algorithm.

This example can take any geometry and will relax it
according to the siesta input options:

 - MD.MaxForceTol
 - MD.MaxCGDispl

One should note that the FIRE algorithm first converges
when the total force (norm) on the atoms are below the 
tolerance. This is contrary to the SIESTA default which
is a force tolerance for the individual directions,
i.e. max-direction force.

This example is prepared to easily create
a combined relaxation of several FIRE algorithms
simultaneously. In some cases this is shown to
speed up the convergence because an average is taken
over several optimizations.

This example defaults to two simultaneous FIRE algorithms
which seems adequate in most situations.

--]]

-- Load the FLOS module
local flos = require "flos"

local FIRE = {}
-- In this example we take a mean of 4 different methods
FIRE[1] = flos.FIRE:new({dt_init = 1., direction="global", correct="local"})
FIRE[2] = flos.FIRE:new({dt_init = 1., direction="global", correct="global"})
FIRE[3] = flos.FIRE:new({dt_init = 1., direction="local", correct="local"})
FIRE[4] = flos.FIRE:new({dt_init = 1., direction="local", correct="global"})
-- To use more simultaneously simply add a
-- new line... with a separate FIRE algorithm.

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
      -- We also need the mass for scaling the displacments
      siesta_get({"MD.MaxDispl",
		  "MD.MaxForceTol",
		  "geom.mass"})

      -- Print information
      if siesta.IONode then
	 -- empty line
	 print("\nLUA convergence information for the FIRE algorithms:")
      end

      -- Ensure we update the convergence criteria
      -- from SIESTA (in this way one can ensure siesta options)
      for i = 1, #FIRE do
	 
	 FIRE[i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
	 FIRE[i].max_dF = siesta.MD.MaxDispl / Unit.Ang
	 FIRE[i].set_mass(siesta.geom.mass)

	 -- Print information
	 if siesta.IONode then
	    FIRE[i]:info()
	 end
      end

   end

   if siesta.state == siesta.MOVE then
      
      -- Here we are doing the actual FIRE algorithm.
      -- We retrieve the current coordinates, the forces
      -- and whether the geometry has relaxed
      siesta_get({"geom.xa",
		  "geom.fa",
		  "MD.Relaxed"})

      ret_tbl = siesta_move(siesta)
      
   end

   siesta_return(ret_tbl)
end

function siesta_move(siesta)

   -- Retrieve the atomic coordinates and the forces
   local xa = flos.Array.from(siesta.geom.xa) / Unit.Ang
   -- Note the FIRE requires the gradient, and
   -- the force is the negative gradient.
   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV

   -- Perform step (initialize arrays to do averaging if more
   -- FIRE algorithms are in use).
   local all_xa = {}
   local weight = {}
   local sum_w = 0.
   for i = 1, #FIRE do
      
      -- Calculate the next optimized structure (that
      -- minimizes the Hessian)
      all_xa[i] = FIRE[i]:optimize(xa, fa)

      -- Get the optimization length for calculating
      -- the best average.
      weight[i] = FIRE[i].weight
      sum_w = sum_w + weight[i]
      
   end

   -- Normalize according to the weighing scheme.
   -- We also print-out the weights for the algorithms
   -- if there are more than one of the FIRE algorithms
   -- running simultaneously.
   local s = ""
   for i = 1, #FIRE do
      
      weight[i] = weight[i] / sum_w
      s = s .. ", " .. string.format("%7.4f", weight[i])
      
   end
   if siesta.IONode and #FIRE > 1 then
      print("\nFIRE weighted average: ", s:sub(3))
   end

   -- Calculate the new coordinates and figure out
   -- if the algorithms has been optimized.
   local out_xa = all_xa[1] * weight[1]
   local relaxed = FIRE[1].is_optimized
   for i = 2, #FIRE do
      
      out_xa = out_xa + all_xa[i] * weight[i]
      relaxed = relaxed and FIRE[i].is_optimized
      
   end
   -- Immediately clean-up to reduce memory overhead (force GC)
   all_xa = nil

   -- Send back new coordinates (convert to Bohr)
   siesta.geom.xa = out_xa * Unit.Ang
   siesta.MD.Relaxed = relaxed
   
   return {"geom.xa",
	   "MD.Relaxed"}
end
