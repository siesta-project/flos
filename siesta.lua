#!/usr/bin/env lua

-- Example of how to use the LBFGS algorithm
-- with SIESTA + LUA

local array = require "array"
local optim = require "optima"

-- Retrieve the LBFGS algorithm
local LBFGS = optim.LBFGS:new()

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
      siesta_get({"MD.MaxDispl", "MD.MaxForceTol"})
      -- Ensure we update the convergence criteria
      -- from SIESTA (in this way one can ensure siesta options)
      LBFGS.tolerance = siesta.MD.MaxForceTol * unit.Ang / unit.eV
      LBFGS.max_dF = siesta.MD.MaxDispl / unit.Ang

      -- Print out, to stdout, some information regarding
      -- the LBFGS algorithm.
      LBFGS:info()

   end

   if siesta.state == siesta.MOVE then
      -- Here we are doing the actual LBFGS algorithm.
      -- We retrieve the current coordinates, the forces
      -- and whether the geometry has relaxed
      siesta_get({"geom.xa", "geom.fa", "MD.Relaxed"})
      ret_tbl = siesta_move(siesta)
   end

   siesta_return(ret_tbl)
end

function siesta_move(siesta)
   
   -- This is were we do the LBFGS algorithm
   xa = array.Array2D.from(siesta.geom.xa) / unit.Ang
   -- Note the LBFGS requires the gradient (the force is the negative
   -- gradient).
   fa = -array.Array2D.from(siesta.geom.fa) * unit.Ang / unit.eV

   --[[
   print('coordinates')
   print(xa, #xa)
   print('forces')
   print(fa, #fa)
   --]]

   -- Perform step
   new_xa = LBFGS:next(xa, fa)
   
   -- Send back new coordinates
   siesta.geom.xa = new_xa * unit.Ang
   siesta.MD.Relaxed = LBFGS.is_optimized
   
   return {"geom.xa", "MD.Relaxed"}
end
