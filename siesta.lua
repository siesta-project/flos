#!/usr/bin/env lua

-- Example of how to use the LBFGS algorithm
-- with SIESTA + LUA

local sfl = require "sfl"

-- Retrieve the LBFGS algorithm
-- Note that in some cases it may be advantegeous to
-- run several simultaneous LBFGS algorithms and taking a weighted
-- averaged between them.
local coord = {}
coord[1] = sfl.LBFGS:new({H0 = 1. / 75.})
coord[2] = sfl.LBFGS:new({H0 = 1. / 50.})
--coord[3] = sfl.LBFGS:new({H0 = 1. / 35.})
local LBFGS_cell = sfl.LBFGS:new()

-- SIESTA unit conversion table
local Unit = siesta.Units


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
      siesta_get({"MD.MaxDispl",
		  "MD.MaxForceTol",
		  "MD.MaxStressTol"})

      -- Ensure we update the convergence criteria
      -- from SIESTA (in this way one can ensure siesta options)
      for i = 1, #coord do
	 coord[i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
	 coord[i].max_dF = siesta.MD.MaxDispl / Unit.Ang

	 -- Print information
	 if siesta.IONode then
	    coord[i]:info()
	 end
      end

      -- Store the cell tolerance (in eV/Ang^3)
      LBFGS_cell.tolerance = siesta.MD.MaxStressTol * Unit.Ang ^ 3 / Unit.eV

      -- Print allowed values on can interact with
      if siesta.IONode then
	 --siesta.print_allowed()
      end

   end

   if siesta.state == siesta.MOVE then
      -- Here we are doing the actual LBFGS algorithm.
      -- We retrieve the current coordinates, the forces
      -- and whether the geometry has relaxed
      siesta_get({"geom.xa",
		  "geom.fa",
		  "geom.cell",
		  "geom.stress",
		  "MD.Relaxed"})
      ret_tbl = siesta_move(siesta)
   end

   siesta_return(ret_tbl)
end

function siesta_move(siesta)

   -- Grab cell and calculate cell volume
   local cell = sfl.Array2D.from(siesta.geom.cell) / Unit.Ang
   local vol = cell[1]:cross(cell[2]):dot(cell[3])

   -- First get the stress (in eV/Ang^3)
   local tmp = sfl.Array2D.from(siesta.geom.stress) * Unit.Ang ^ 3 / Unit.eV
   -- Convert to 2x3
   local stress = sfl.Array2D:new(2, 3)
   stress[1][1] = tmp[1][1]
   stress[1][2] = tmp[2][2]
   stress[1][3] = tmp[3][3]
   stress[2][1] = tmp[2][3]
   stress[2][2] = tmp[1][3]
   stress[2][3] = tmp[1][2]

   
   -- This is were we do the LBFGS algorithm
   local xa = sfl.Array2D.from(siesta.geom.xa) / Unit.Ang
   -- Note the LBFGS requires the gradient
   -- The force is the negative gradient.
   local fa = -sfl.Array2D.from(siesta.geom.fa) * Unit.Ang / Unit.eV

   -- Perform step (initialize array)
   local all_xa = {}
   local weight = {}
   local sum_w = 0.
   for i = 1, #coord do
      all_xa[i] = coord[i]:optimize(xa, fa)
      weight[i] = coord[i].rho_optimized
      sum_w = sum_w + weight[i]
   end
   -- Calculate the proper weights
   -- This weighting scheme will favor the largest
   -- change until the Hessians converge in which case
   -- both will result in the same displacement and the
   -- same updated coordinates.
   local s = ""
   for i = 1, #coord do
      weight[i] = weight[i] / sum_w
      s = s .. ", " .. string.format("%7.4f", tostring(weight[i]))
   end
   if siesta.IONode and #coord > 1 then
      print("LBFGS weighted average: ", s:sub(3))
   end

   -- Calculate the new coordinates
   local out_xa = xa * 0.
   local relaxed = true
   for i = 1, #coord do
      out_xa = out_xa + all_xa[i] * weight[i]
      relaxed = relaxed and coord[i].is_optimized
   end
   
   -- Send back new coordinates
   siesta.geom.xa = out_xa * Unit.Ang
   siesta.MD.Relaxed = relaxed
   
   return {"geom.xa",
	   "MD.Relaxed"}
end
