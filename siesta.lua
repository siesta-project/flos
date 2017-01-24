#!/usr/bin/env lua

-- Example of how to use the LBFGS algorithm
-- with SIESTA + LUA

local array = require "array"
local optim = require "optima"

-- Retrieve the LBFGS algorithm
local LBFGS_coord = optim.LBFGS:new()
local LBFGS_cell = optim.LBFGS:new()

local unit = {
   Ang = 1. / 0.529177,
   eV = 1. / 13.60580,
}


function siesta_comm()
   --[[
      Retrieve siesta information.
   --]]

   -- Do the actual communication with fortran
   if siesta.state == siesta.INITIALIZE then
      -- In the initialization step we request the
      -- convergence criteria, MD.MaxDispl and MD.MaxForceTol
      -- Note that the internal siesta units are Ry and Bohr,
      -- so we convert
      siesta_get({"MD.MaxDispl", "MD.MaxForceTol",
		  "MD.MaxStressTol"})
      -- Ensure we update the convergence criteria
      -- from SIESTA (in this way one can ensure siesta options)
      LBFGS_coord.tolerance = siesta.MD.MaxForceTol * unit.Ang / unit.eV
      LBFGS_coord.max_dF = siesta.MD.MaxDispl / unit.Ang

      -- Print out, to stdout, some information regarding
      -- the LBFGS algorithm.
      LBFGS_coord:info()

      -- Store the cell tolerance
      LBFGS_cell.tolerance = siesta.MD.MaxStressTol

   end

   if siesta.state == siesta.MOVE then
      -- Here we are doing the actual LBFGS algorithm.
      -- We retrieve the current coordinates, the forces
      -- and whether the geometry has relaxed
      siesta_get({"geom.xa", "geom.fa",
		  "geom.cell", "geom.stress",
		  "MD.Relaxed"})
      ret_tbl = siesta_move(siesta)
   end

   siesta_return(ret_tbl)
end

function siesta_move(siesta)

   local cell = array.Array2D.from(siesta.geom.cell)
   
   -- First get the stress
   local tmp = array.Array2D.from(siesta.geom.stress)
   -- Convert to 2x3
   local stress = array.Array2D:new(2, 3)
   stress[1][1] = tmp[1][1]
   stress[1][2] = tmp[2][2]
   stress[1][3] = tmp[3][3]
   stress[2][1] = tmp[1][2]
   stress[2][2] = tmp[2][2]
   stress[2][3] = tmp[3][3]

   for i = 1, 2 do
      for j = 1 , 3
   
   -- This is were we do the LBFGS algorithm
   local xa = array.Array2D.from(siesta.geom.xa) / unit.Ang
   -- Note the LBFGS requires the gradient (the force is the negative
   -- gradient).
   local fa = -array.Array2D.from(siesta.geom.fa) * unit.Ang / unit.eV

   --[[
   print('coordinates')
   print(xa, #xa)
   print('forces')
   print(fa, #fa)
   --]]

   -- Perform step
   local new_xa = LBFGS:next(xa, fa)
   
   -- Send back new coordinates
   siesta.geom.xa = new_xa * unit.Ang
   siesta.MD.Relaxed = LBFGS.is_optimized
   
   return {"geom.xa", "MD.Relaxed"}
end
