Tutorials of FLOS
=================

.. figure:: ./_images/3.png
  :width: 400px

  What Flos Could Do...!


Optimizations
-------------

Mech Cutoff
...........

This tutorial can take any system and will perform a series of calculations with increasing
Mesh.Cutoff and it will write-out a table file to be plotted which contains the Mesh.Cutoff vs Energy.

The task steps is the following:
  (1) Read Starting Mesh cutoff (``siesta.state= siesta.INITIALIZE`` )
  (2) Run siesta with the Starting Mesh (``siesta.state= siesta.INI_MD`` )
  (3) Save the Mesh and Enegy then increase the Mesh cutoff and Run siesta with new mesh (``siesta.state == siesta.MOVE``) and (user defined function)
  (4) If reach to last mesh write Mesh cutoff vs Energy in file (``siesta.state == siesta.ANALYSIS``)

For optimizing our mesh we may need 3 values:

 (1) cutoff_start
 (2) cutoff_end
 (3) cutoff_step

To do so we have these lines in our script: ::

   -- Load the FLOS module
   local flos = require "flos"

   local cutoff_start = 150.
   local cutoff_end = 650.
   local cutoff_step = 50.

   -- Create array of cut-offs
   local cutoff = flos.Array.range(cutoff_start, cutoff_end, cutoff_step)
   local Etot = flos.Array.zeros(#cutoff)
   -- Initial cut-off element
   local icutoff = 1

.. NOTE::
   
        In above lines we use flos array class to generate our array cutoffs

For user defined function we have: ::

  function step_cutoff(cur_cutoff)
   if icutoff < cutoff then
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

Which only increase the value of mesh with step value cur_cutoff.

Now we are ready to write our main siesta communicator function: ::
  
  function siesta_comm()
   -- Do the actual communication with SIESTA
   if siesta.state == siesta.INITIALIZE then
      -- In the initialization step we request the
      -- Mesh cutoff (merely to be able to set it
      siesta.receive({"Mesh.Cutoff.Minimum"})
      -- Overwrite to ensure we start from the beginning
      siesta.Mesh.Cutoff.Minimum = cutoff[icutoff]
      IOprint( ("\nLUA: starting mesh-cutoff: %8.3f Ry\n"):format(cutoff[icutoff]) )
      siesta.send({"Mesh.Cutoff.Minimum"})
   end
   if siesta.state == siesta.INIT_MD then
      siesta.receive({"Mesh.Cutoff.Used"})
      -- Store the used meshcutoff for this iteration
      cutoff[icutoff] = siesta.Mesh.Cutoff.Used
   end
   if siesta.state == siesta.MOVE then
      -- Retrieve the total energy and update the
      -- meshcutoff for the next cycle
      -- Notice, we do not move, or change the geometry
      -- or cell-vectors.
      siesta.receive({"E.total","MD.Relaxed"})
      Etot[icutoff] = siesta.E.total
      -- Step the meshcutoff for the next iteration
      if step_cutoff(cutoff[icutoff]) then
          siesta.Mesh.Cutoff.Minimum = cutoff[icutoff]
      else
          siesta.MD.Relaxed = true
      end    
      siesta.send({"Mesh.Cutoff.Minimum","MD.Relaxed"})
   end
   if siesta.state == siesta.ANALYSIS then
      local file = io.open("meshcutoff_E.dat", "w")
      file:write("# Mesh-cutoff vs. energy\n")
      -- We write out a table with mesh-cutoff, the difference between
      -- the last iteration, and the actual value
      file:write( ("%8.3e  %17.10e  %17.10e\n"):format(cutoff[1], 0., Etot[1]) )
      for i = 2, #cutoff do
      file:write( ("%8.3e  %17.10e  %17.10e\n"):format(cutoff[i], Etot[i]-Etot[i-1], Etot[i]) )
   end
      file:close()
   end


.. NOTE::
         The important thing to take away is that, siesta in ``siesta.MOVE`` remains to that state unless we ``siesta.MD.Relaxed = true`` .

k points
........

This example will perform a series of calculations with increasing
k-Mesh and it will write-out a table file to be plotted which contains the k-Mesh vs Energy.

The Initialization is : ::

 local kpoint_start_x = 1.
 local kpoint_end_x = 10.
 local kpoint_step_x = 3.
 local kpoint_start_y = 1.
 local kpoint_end_y = 10
 local kpoint_step_y = 3.
 local kpoint_start_z = 1.
 local kpoint_end_z = 1.
 local kpoint_step_z = 1.
 local flos = require "flos"
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
 local ikpoint_x = 1
 local ikpoint_y = 1
 local ikpoint_z = 1
 local kpoints_num_temp = 0 

For user defined function we have: ::
 
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

For our main siesta communicator function we have: ::

 function siesta_comm()

   if siesta.state == siesta.INITIALIZE then
      siesta.receive({"BZ.k.Matrix"})
      kpoints = flos.Array.from(siesta.BZ.k.Matrix)
      IOprint ("LUA: Provided k-point :" )--.. tostring( kpoints_num))
      kpoint_mesh = kpoints
      IOprint("LUA: k_x :\n" .. tostring(kpoint_cutoff_x))
      IOprint("LUA: k_y :\n" .. tostring(kpoint_cutoff_y))
      IOprint("LUA: k_z :\n" .. tostring(kpoint_cutoff_z))
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
   end

   if siesta.state == siesta.MOVE then

      siesta.receive({"E.total",
                      "MD.Relaxed"})

      Etot[ikpoint_x ] = siesta.E.total

      if step_kpointf_x(kpoint_cutoff_x[ikpoint_x]) then
         kpoint_mesh[1][1] = kpoint_cutoff_x[ikpoint_x]
         if step_kpointf_y(kpoint_cutoff_y[ikpoint_y]) then
            kpoint_mesh[2][2] = kpoint_cutoff_y[ikpoint_y]
            if step_kpointf_z(kpoint_cutoff_z[ikpoint_z]) then
               kpoint_mesh[3][3] = kpoint_cutoff_z[ikpoint_z]
            end
          end
      end

      siesta.BZ.k.Matrix = kpoint_mesh

      kpoints_num_temp = kpoints_num_temp + 1
      if kpoints_num == kpoints_num_temp then
         siesta.MD.Relaxed = true
      else

      IOprint ("LUA: Number of k-points (".. tostring(kpoints_num_temp+1) .. "/" .. tostring(Total_kpoints:max()).. ")" )
      IOprint("LUA: Next Kpoint to Be Used :\n" .. tostring(siesta.BZ.k.Matrix))
      end

      siesta.send({"BZ.k.Matrix", "MD.Relaxed"})

   end

   if siesta.state == siesta.ANALYSIS then
      local file = io.open("k_meshcutoff_E.dat", "w")
      file:write("# kpoint-Mesh-cutoff vs. energy\n")
      file:write( ("%8.3e %17.10e  %17.10e\n"):format(1, Etot[1], 0.) )
      for i = 2, Total_kpoints:max()  do
         file:write( ("%8.3e %17.10e  %17.10e\n"):format(i,Etot[i], Etot[i]-Etot[i-1]) )
      end
      file:close()
   end


Relaxations
-----------

Whithin Lua we could have plenty of options for Relaxations. Below there are couple of those methods to apply. 


Cell Relaxation
...................
This example can take any geometry and will relax the
cell vectors according to the siesta input options:

 - MD.MaxStressTol
 - MD.MaxDispl

This example defaults to two simultaneous LBFGS algorithms
which seems adequate in most situations.

For user defined function we have move function which take care of relaxations part: ::

 function siesta_move(siesta)

   local cell = flos.Array.from(siesta.geom.cell) / Unit.Ang
   local xa = flos.Array.from(siesta.geom.xa) / Unit.Ang
   local tmp = -flos.Array.from(siesta.geom.stress) * Unit.Ang ^ 3 / Unit.eV
   local stress = flos.Array.empty(6)
   stress[1] = tmp[1][1]
   stress[2] = tmp[2][2]
   stress[3] = tmp[3][3]
   stress[4] = (tmp[2][3] + tmp[3][2]) * 0.5
   stress[5] = (tmp[1][3] + tmp[3][1]) * 0.5
   stress[6] = (tmp[1][2] + tmp[2][1]) * 0.5
   tmp = nil
   stress = stress * stress_mask
   local vol = cell[1]:cross(cell[2]):dot(cell[3])
   local all_strain = {}
   local weight = flos.Array.empty(#LBFGS)
   for i = 1, #LBFGS do
      all_strain[i] = LBFGS[i]:optimize(strain, stress * vol)
      LBFGS[i]:optimized(stress)
      weight[i] = LBFGS[i].weight
   end

   weight = weight / weight:sum()
   if #LBFGS > 1 then
      IOprint("\nLBFGS weighted average: ", weight)
   end

   local out_strain = all_strain[1] * weight[1]
   local relaxed = LBFGS[1]:optimized()
   for i = 2, #LBFGS do
      out_strain = out_strain + all_strain[i] * weight[i]
      relaxed = relaxed and LBFGS[i]:optimized()
   end
   all_strain = nil

   strain = out_strain * stress_mask
   out_strain = nil

   local dcell = flos.Array( cell.shape )
   dcell[1][1] = 1.0 + strain[1]
   dcell[1][2] = 0.5 * strain[6]
   dcell[1][3] = 0.5 * strain[5]
   dcell[2][1] = 0.5 * strain[6]
   dcell[2][2] = 1.0 + strain[2]
   dcell[2][3] = 0.5 * strain[4]
   dcell[3][1] = 0.5 * strain[5]
   dcell[3][2] = 0.5 * strain[4]
   dcell[3][3] = 1.0 + strain[3]

   local out_cell = cell_first:dot(dcell)
   dcell = nil

   weight = weight / weight:sum()
   if #LBFGS > 1 then
      IOprint("\nLBFGS weighted average: ", weight)
   end

   local out_strain = all_strain[1] * weight[1]
   local relaxed = LBFGS[1]:optimized()
   for i = 2, #LBFGS do
      out_strain = out_strain + all_strain[i] * weight[i]
      relaxed = relaxed and LBFGS[i]:optimized()
   end
   all_strain = nil

   strain = out_strain * stress_mask
   out_strain = nil

   local dcell = flos.Array( cell.shape )
   dcell[1][1] = 1.0 + strain[1]
   dcell[1][2] = 0.5 * strain[6]
   dcell[1][3] = 0.5 * strain[5]
   dcell[2][1] = 0.5 * strain[6]
   dcell[2][2] = 1.0 + strain[2]
   dcell[2][3] = 0.5 * strain[4]
   dcell[3][1] = 0.5 * strain[5]
   dcell[3][2] = 0.5 * strain[4]
   dcell[3][3] = 1.0 + strain[3]

   local out_cell = cell_first:dot(dcell)
   dcell = nil

   local lat = flos.Lattice:new(cell)
   local fxa = lat:fractional(xa)
   xa = fxa:dot(out_cell)
   lat = nil
   fxa = nil

   siesta.geom.cell = out_cell * Unit.Ang
   siesta.geom.xa = xa * Unit.Ang
   siesta.MD.Relaxed = relaxed

   return {"geom.cell",
           "geom.xa",
           "MD.Relaxed"}
 end

For our main siesta communicator function we have: ::

 function siesta_comm()

   local ret_tbl = {}

   if siesta.state == siesta.INITIALIZE then

      siesta.receive({"geom.cell",
                      "MD.Relax.Cell",
                      "MD.MaxDispl",
                      "MD.MaxStressTol"})

      if not siesta.MD.Relax.Cell then

         siesta.MD.Relax.Cell = true
         ret_tbl = {"MD.Relax.Cell"}

      end

      IOprint("\nLUA convergence information for the LBFGS algorithms:")

      cell_first = flos.Array.from(siesta.geom.cell) / Unit.Ang

      for i = 1, #LBFGS do
         LBFGS[i].tolerance = siesta.MD.MaxStressTol * Unit.Ang ^ 3 / Unit.eV
         LBFGS[i].max_dF = siesta.MD.MaxDispl / Unit.Ang

         if siesta.IONode then
            LBFGS[i]:info()
         end
      end

   end
 
   if siesta.state == siesta.MOVE then
      siesta.receive({"geom.cell",
                      "geom.xa",
                      "geom.stress",
                      "MD.Relaxed"})
      ret_tbl = siesta_move(siesta)
   end

   siesta.send(ret_tbl)
 end


Cell and Geometry Relaxation
............................

This example can take any geometry and will relax the
cell vectors according to the siesta input options:

 - MD.MaxForceTol
 - MD.MaxStressTol
 - MD.MaxCGDispl

To initiate we have : ::

 local flos = require "flos"

 -- Create the two LBFGS algorithms with
 -- initial Hessians 1/75 and 1/50
 local geom = {}
 geom[1] = flos.LBFGS{H0 = 1. / 75.}
 geom[2] = flos.LBFGS{H0 = 1. / 50.}

 local lattice = {}
 lattice[1] = flos.LBFGS{H0 = 1. / 75.}
 lattice[2] = flos.LBFGS{H0 = 1. / 50.}

 -- Grab the unit table of siesta (it is already created
 -- by SIESTA)
 local Unit = siesta.Units

 -- Initial strain that we want to optimize to minimize
 -- the stress.
 local strain = flos.Array.zeros(6)
 -- Mask which directions we should relax
 --   [xx, yy, zz, yz, xz, xy]
 -- Default to all.
 local stress_mask = flos.Array.ones(6)

 -- To only relax the diagonal elements you may do this:
 stress_mask[4] = 0.
 stress_mask[5] = 0.
 stress_mask[6] = 0.

 -- The initial cell
 local cell_first

 -- This variable controls which relaxation is performed
 -- first.
 -- If true, it starts by relaxing the geometry (coordinates)
 --    (recommended)
 -- If false, it starts by relaxing the cell vectors.
 local relax_geom = true

For user defined function we have move couple of functions. The Fucntion which take care of Stress part is : ::

 function stress_from_voigt(voigt)
   
   local stress = flos.Array.empty(3, 3)
   stress[1][1] = voigt[1]
   stress[1][2] = voigt[6]
   stress[1][3] = voigt[5]
   stress[2][1] = voigt[6]
   stress[2][2] = voigt[2]
   stress[2][3] = voigt[4]
   stress[3][1] = voigt[5]
   stress[3][2] = voigt[4]
   stress[3][3] = voigt[3]

   return stress
 end

The Function which take care of geometry relaxations part: ::

 function siesta_geometry(siesta)

   local xa = siesta.geom.xa
   local fa = siesta.geom.fa

   local all_xa = {}
   local weight = flos.Array.empty(#geom)
   for i = 1, #geom do
      all_xa[i] = geom[i]:optimize(xa, fa)
      weight[i] = geom[i].weight
   end

   weight = weight / weight:sum()
   if #geom > 1 then
      IOprint("\nGeometry weighted average: ", weight)
   end

   local out_xa = all_xa[1] * weight[1]
   for i = 2, #geom do
      out_xa = out_xa + all_xa[i] * weight[i]
   end
   all_xa = nil

   siesta.geom.xa = out_xa * Unit.Ang

   return {"geom.xa"}
 end

The Function which take care of cell relaxations part: ::

 function siesta_cell(siesta)

   local cell = siesta.geom.cell
   local xa = siesta.geom.xa
   local stress = stress_to_voigt(siesta.geom.stress)
   stress = stress * stress_mask

   local vol = cell[1]:cross(cell[2]):dot(cell[3])

   local all_strain = {}
   local weight = flos.Array.empty(#lattice)
   for i = 1, #lattice do
      all_strain[i] = lattice[i]:optimize(strain, stress * vol)
      lattice[i]:optimized(stress)
      weight[i] = lattice[i].weight
   end

   weight = weight / weight:sum()
   if #lattice > 1 then
      IOprint("\nLattice weighted average: ", weight)
   end

   local out_strain = all_strain[1] * weight[1]
   for i = 2, #lattice do
      out_strain = out_strain + all_strain[i] * weight[i]
   end
   all_strain = nil

   strain = out_strain * stress_mask
   out_strain = nil

   local dcell = flos.Array( cell.shape )
   dcell[1][1] = 1.0 + strain[1]
   dcell[1][2] = 0.5 * strain[6]
   dcell[1][3] = 0.5 * strain[5]
   dcell[2][1] = 0.5 * strain[6]
   dcell[2][2] = 1.0 + strain[2]
   dcell[2][3] = 0.5 * strain[4]
   dcell[3][1] = 0.5 * strain[5]
   dcell[3][2] = 0.5 * strain[4]
   dcell[3][3] = 1.0 + strain[3]

   local out_cell = cell_first:dot(dcell)
   dcell = nil

   local lat = flos.Lattice:new(cell)
   local fxa = lat:fractional(xa)
   xa = fxa:dot(out_cell)
   lat = nil
   fxa = nil

   siesta.geom.cell = out_cell * Unit.Ang
   siesta.geom.xa = xa * Unit.Ang

   return {"geom.cell",
           "geom.xa"}
 end
                                      

For our main siesta communicator function we have: ::

 function siesta_comm()

   local ret_tbl = {}

   if siesta.state == siesta.INITIALIZE then
      siesta.receive({"geom.cell",
                      "MD.Relax.Cell",
                      "MD.MaxDispl",
                      "MD.MaxForceTol",
                      "MD.MaxStressTol"})

      if not siesta.MD.Relax.Cell then

         siesta.MD.Relax.Cell = true
         ret_tbl = {"MD.Relax.Cell"}

      end

      IOprint("\nLUA convergence information for the LBFGS algorithms:")

      cell_first = flos.Array.from(siesta.geom.cell) / Unit.Ang

      IOprint("Lattice optimization:")
      for i = 1, #lattice do
         lattice[i].tolerance = siesta.MD.MaxStressTol * Unit.Ang ^ 3 / Unit.eV
         lattice[i].max_dF = siesta.MD.MaxDispl / Unit.Ang

         if siesta.IONode then
            lattice[i]:info()
         end
      end

      IOprint("\nGeometry optimization:")
      for i = 1, #geom do
         geom[i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
         geom[i].max_dF = siesta.MD.MaxDispl / Unit.Ang

         if siesta.IONode then
            geom[i]:info()
         end
      end

      if relax_geom then
         IOprint("\nLUA: Starting with geometry relaxation!\n")
      else
         IOprint("\nLUA: Starting with cell relaxation!\n")
      end

   end

   if siesta.state == siesta.MOVE then

      siesta.receive({"geom.cell",
                      "geom.xa",
                      "geom.fa",
                      "geom.stress",
                      "MD.Relaxed"})
      ret_tbl = siesta_move(siesta)
   end

   siesta.send(ret_tbl)
 end

For the Move Part we have : ::

 function siesta_move(siesta)
   siesta.geom.cell = flos.Array.from(siesta.geom.cell) / Unit.Ang
   siesta.geom.xa = flos.Array.from(siesta.geom.xa) / Unit.Ang
   siesta.geom.fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV
   siesta.geom.stress = -flos.Array.from(siesta.geom.stress) * Unit.Ang ^ 3 / Unit.eV

   local voigt = stress_to_voigt(siesta.geom.stress)
   voigt = voigt * stress_mask
   local conv_lattice = lattice[1]:optimized(voigt)
   voigt = nil

   local conv_geom = geom[1]:optimized(siesta.geom.fa)

   if conv_lattice and conv_geom then

      siesta.MD.Relaxed = true
      return {'MD.Relaxed'}

   end

   if relax_geom and conv_geom then

      relax_geom = false
      for i = 1, #geom do
         geom[i]:reset()
      end

      cell_first = siesta.geom.cell:copy()

      IOprint("\nLUA: switching to cell relaxation!\n")

   elseif (not relax_geom) and conv_lattice then

      relax_geom = true
      for i = 1, #lattice do
         lattice[i]:reset()
      end

      IOprint("\nLUA: switching to geometry relaxation!\n")

   end

   if relax_geom then
      return siesta_geometry(siesta)
   else
      return siesta_cell(siesta)
   end

 end



Geometry Relaxation with CG
...........................

This example can take any geometry and will relax it
according to the siesta input options:

 - MD.MaxForceTol
 - MD.MaxCGDispl

One should note that the CG algorithm first converges
when the total force (norm) on the atoms are below the 
tolerance. This is contrary to the SIESTA default which
is a force tolerance for the individual directions,
i.e. max-direction force.

This example is prepared to easily create
a combined relaxation of several CG algorithms
simultaneously. In some cases this is shown to
speed up the convergence because an average is taken
over several optimizations.

The Initialization is : ::

 local flos = require "flos"

 local CG = {}
 CG[1] = flos.CG{beta='PR', line=flos.Line{optimizer = flos.LBFGS{H0 = 1. / 75.} } }
 CG[2] = flos.CG{beta='PR', line=flos.Line{optimizer = flos.LBFGS{H0 = 1. / 50.} } }
 local Unit = siesta.Units

For the Move Part we have : ::

 function siesta_move(siesta)

   local xa = flos.Array.from(siesta.geom.xa) / Unit.Ang
   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV

   local all_xa = {}
   local weight = flos.Array.empty(#CG)
   for i = 1, #CG do
      all_xa[i] = CG[i]:optimize(xa, fa)
      weight[i] = CG[i].weight

   end

   weight = weight / weight:sum()
   if #CG > 1 then
      IOprint("\nCG weighted average: ", weight)
   end

   local out_xa = all_xa[1] * weight[1]
   local relaxed = CG[1]:optimized()
   for i = 2, #CG do

      out_xa = out_xa + all_xa[i] * weight[i]
      relaxed = relaxed and CG[i]:optimized()

   end
   all_xa = nil

   siesta.geom.xa = out_xa * Unit.Ang
   siesta.MD.Relaxed = relaxed

   return {"geom.xa",
           "MD.Relaxed"}
 end

For our main siesta communicator function we have: ::

 function siesta_comm()

   local ret_tbl = {}

   if siesta.state == siesta.INITIALIZE then
      siesta.receive({"MD.MaxDispl",
                      "MD.MaxForceTol"})

      IOprint("\nLUA convergence information for the LBFGS algorithms:")
      for i = 1, #CG do
         CG[i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
         CG[i].max_dF = siesta.MD.MaxDispl / Unit.Ang
         CG[i].line.tolerance = CG[i].tolerance
         CG[i].line.max_dF = CG[i].max_dF -- this is not used
         CG[i].line.optimizer.tolerance = CG[i].tolerance -- this is not used
         CG[i].line.optimizer.max_dF = CG[i].max_dF -- this is used
         if siesta.IONode then
            CG[i]:info()
         end
      end

   end

   if siesta.state == siesta.MOVE then
      siesta.receive({"geom.xa",
                      "geom.fa",
                      "MD.Relaxed"})
      ret_tbl = siesta_move(siesta)
   end

   siesta.send(ret_tbl)
 end


Geometry Relaxation with Fire
.............................

This example can take any geometry and will relax it
according to the siesta input options:

 - MD.MaxForceTol
 - MD.MaxCGDispl

One should note that the FIRE algorithm first converges
when the total force (norm) on the atoms are below the
tolerance. This is contrary to the SIESTA default which
is a force tolerance for the individual directions,
i.e. max-direction force.

The Initialization is : ::

 local flos = require "flos"
 local FIRE = {}
 local dt_init = 0.5
 FIRE[1] = flos.FIRE{dt_init = dt_init, direction="global", correct="local"}
 FIRE[2] = flos.FIRE{dt_init = dt_init, direction="global", correct="global"}
 FIRE[3] = flos.FIRE{dt_init = dt_init, direction="local", correct="local"}
 FIRE[4] = flos.FIRE{dt_init = dt_init, direction="local", correct="global"}
 local Unit = siesta.Units

For the Move Part we have : ::

 function siesta_move(siesta)

   local xa = flos.Array.from(siesta.geom.xa) / Unit.Ang
   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV

   local all_xa = {}
   local weight = flos.Array.empty(#FIRE)
   for i = 1, #FIRE do
      all_xa[i] = FIRE[i]:optimize(xa, fa)
      weight[i] = FIRE[i].weight

   end

   weight = weight / weight:sum()
   if #FIRE > 1 then
      IOprint("\nFIRE weighted average: ", weight)
   end

   local out_xa = all_xa[1] * weight[1]
   local relaxed = FIRE[1]:optimized()
   for i = 2, #FIRE do
      out_xa = out_xa + all_xa[i] * weight[i]
      relaxed = relaxed and FIRE[i]:optimized()
   end
   all_xa = nil

   siesta.geom.xa = out_xa * Unit.Ang
   siesta.MD.Relaxed = relaxed

   return {"geom.xa",
           "MD.Relaxed"}
 end

For our main siesta communicator function we have: ::

 function siesta_comm()

   local ret_tbl = {}

   if siesta.state == siesta.INITIALIZE then

      siesta.receive({"MD.MaxDispl",
                      "MD.MaxForceTol",
                      "geom.mass"})

      IOprint("\nLUA convergence information for the FIRE algorithms:")
      for i = 1, #FIRE do

         FIRE[i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
         FIRE[i].max_dF = siesta.MD.MaxDispl / Unit.Ang
         FIRE[i].set_mass(siesta.geom.mass)

         if siesta.IONode then
            FIRE[i]:info()
         end
      end
   end

   if siesta.state == siesta.MOVE then

      siesta.receive({"geom.xa",
                      "geom.fa",
                      "MD.Relaxed"})

      ret_tbl = siesta_move(siesta)

   end

   siesta.send(ret_tbl)
 
 end



Geometry Relaxation with LBFGS
..............................

This example can take any geometry and will relax it
according to the siesta input options:

 - MD.MaxForceTol
 - MD.MaxCGDispl

One should note that the LBFGS algorithm first converges
when the total force (norm) on the atoms are below the
tolerance. This is contrary to the SIESTA default which
is a force tolerance for the individual directions,
i.e. max-direction force.

The Initialization is : ::

 local flos = require "flos"

 local LBFGS = {}
 LBFGS[1] = flos.LBFGS{H0 = 1. / 75.}
 LBFGS[2] = flos.LBFGS{H0 = 1. / 50.}
 local Unit = siesta.Units

For the Move Part we have : ::

 function siesta_move(siesta)

   local xa = flos.Array.from(siesta.geom.xa) / Unit.Ang
   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV

   local all_xa = {}
   local weight = flos.Array.empty(#LBFGS)
   for i = 1, #LBFGS do
      all_xa[i] = LBFGS[i]:optimize(xa, fa)
      weight[i] = LBFGS[i].weight

   end

   weight = weight / weight:sum()
   if #LBFGS > 1 then
      IOprint("\nLBFGS weighted average: ", weight)
   end

   local out_xa = all_xa[1] * weight[1]
   local relaxed = LBFGS[1]:optimized()
   for i = 2, #LBFGS do
      out_xa = out_xa + all_xa[i] * weight[i]
      relaxed = relaxed and LBFGS[i]:optimized()

   end
   all_xa = nil

   siesta.geom.xa = out_xa * Unit.Ang
   siesta.MD.Relaxed = relaxed

   return {"geom.xa",
           "MD.Relaxed"}
 end

For our main siesta communicator function we have: ::

 function siesta_comm()
   
   local ret_tbl = {}
   if siesta.state == siesta.INITIALIZE then
      siesta.receive({"MD.MaxDispl",
                      "MD.MaxForceTol"})

      IOprint("\nLUA convergence information for the LBFGS algorithms:")
      for i = 1, #LBFGS do
         LBFGS[i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
         LBFGS[i].max_dF = siesta.MD.MaxDispl / Unit.Ang
         if siesta.IONode then
            LBFGS[i]:info()
         end
      end

   end

   if siesta.state == siesta.MOVE then
      siesta.receive({"geom.xa",
                      "geom.fa",
                      "MD.Relaxed"})
      ret_tbl = siesta_move(siesta)

   end

   siesta.send(ret_tbl)
 end

Constrained Cell Relaxation
...........................


Finding Transition States Minimum Energy Path (MEP)
---------------------------------------------------

Nudged Elastic Band
...................
Example on how to use an NEB method.

The Initialization is : ::

 local image_label = "image_"
 local n_images = 5
 local k_spring = 1
 local flos = require "flos"
 local images = {}
 
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

 for i = 0, n_images + 1 do
    images[#images+1] = flos.MDStep{R=read_geom(image_label .. i .. ".xyz")}
 end

 local NEB = flos.NEB(images,{k=k_spring})
 if siesta.IONode then
    NEB:info()
 end
 n_images = nil

 local relax = {}
 for i = 1, NEB.n_images do
    relax[i] = {}
    relax[i][1] = flos.CG{beta='PR',restart='Powell', line=flos.Line{optimizer = flos.LBFGS{H0 = 1. / 25.} } }
    if siesta.IONode then
       NEB:info()
     end

 end

 local current_image = 1

 local Unit = siesta.Units

some user define functions: ::

 function siesta_update_DM(old, current)

   if not siesta.IONode then
      return
   end
   local DM = label .. ".DM"
   local old_DM = DM .. "." .. tostring(old)
   local current_DM = DM .. "." .. tostring(current)
   local initial_DM = DM .. ".0"
   local final_DM = DM .. ".".. tostring(NEB.n_images+1)
   print ("The Label of Old DM is : " .. old_DM)
   print ("The Label of Current DM is : " .. current_DM)
   if old==0 and current==0 then
     print("Removing DM for Resuming")
     IOprint("Deleting " .. DM .. " for a clean restart...")
     os.execute("rm " .. DM)
   end

   if 0 <= old and old <= NEB.n_images+1 and NEB:file_exists(DM) then
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

 function siesta_update_xyz(current)
  if not siesta.IONode then
      return
   end
  local xyz_label = image_label ..tostring(current)..".xyz"

  local f=io.open(xyz_label,"w")
  f:write(tostring(#NEB[current].R).."\n \n")
  for i=1,#NEB[current].R do
    f:write(string.format(" %19.17f",tostring(NEB[current].R[i][1])).. "   "..string.format("%19.17f",tostring(NEB[current].R[i][2]))..string.format("   %19.17f",tostring(NEB[current].R[i][3])).."\n")
 end
 f:close()
  --
 end


for the Move Part we have : ::

 function siesta_move(siesta)

   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV
   local E = siesta.E.total / Unit.eV

   NEB[current_image]:set{F=fa, E=E}

   if current_image == 0 then
      current_image = NEB.n_images + 1
      siesta.geom.xa = NEB[current_image].R * Unit.Ang

      IOprint("\nLUA/NEB final state\n")
      return {'geom.xa'}

   elseif current_image == NEB.n_images + 1 then

      current_image = 1

      siesta.geom.xa = NEB[current_image].R * Unit.Ang
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, NEB.n_images))
      return {'geom.xa'}

   elseif current_image < NEB.n_images then
      current_image = current_image + 1
      siesta.geom.xa = NEB[current_image].R * Unit.Ang
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, NEB.n_images))
      return {'geom.xa'}
   end

   local relaxed = true
   IOprint("\nNEB step")
   local out_R = {}
   for img = 1, NEB.n_images do

      local F = NEB:force(img, siesta.IONode)
      IOprint("NEB: max F on image ".. img ..
                 (" = %10.5f, climbing = %s"):format(F:norm():max(),
                                                     tostring(NEB:climbing(img))) )
      local all_xa, weight = {}, flos.Array( #relax[img] )
      for i = 1, #relax[img] do
         all_xa[i] = relax[img][i]:optimize(NEB[img].R, F)
         weight[i] = relax[img][i].weight
      end
      weight = weight / weight:sum()

      if #relax[img] > 1 then
         IOprint("\n weighted average for relaxation: ", tostring(weight))
      end

      local out_xa = all_xa[1] * weight[1]
      relaxed = relaxed and relax[img][1]:optimized()
      for i = 2, #relax[img] do
         out_xa = out_xa + all_xa[i] * weight[i]
         relaxed = relaxed and relax[img][i]:optimized()
      end

      out_R[img] = out_xa

   end

   NEB:save( siesta.IONode )

   for img = 1, NEB.n_images do
      NEB[img]:set{R=out_R[img]}
   end
   current_image = 1
   if relaxed then
      siesta.geom.xa = NEB.final.R * Unit.Ang
      IOprint("\nLUA/NEB complete\n")
   else
      siesta.geom.xa = NEB[1].R * Unit.Ang
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, NEB.n_images))
   end

   siesta.MD.Relaxed = relaxed

   return {"geom.xa",
           "MD.Relaxed"}
 end

For our main siesta communicator function we have: ::

 function siesta_comm()

   local ret_tbl = {}

   if siesta.state == siesta.INITIALIZE then
      siesta.receive({"Label",
                      "geom.xa",
                      "MD.MaxDispl",
                      "MD.MaxForceTol"})

      label = tostring(siesta.Label)
      IOprint("\nLUA NEB calculator")

      for img = 1, NEB.n_images do
         IOprint(("\nLUA NEB relaxation method for image %d:"):format(img))
         for i = 1, #relax[img] do
            relax[img][i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
            relax[img][i].max_dF = siesta.MD.MaxDispl / Unit.Ang
            if siesta.IONode then
               relax[img][i]:info()
            end
         end
      end

      siesta.geom.xa = NEB.initial.R * Unit.Ang
      IOprint("\nLUA/NEB initial state\n")
      current_image = 0
      siesta_update_DM(0, current_image)
      siesta_update_xyz(current_image)
      IOprint(NEB[current_image].R)
      ret_tbl = {'geom.xa'}
   end

   if siesta.state == siesta.MOVE then

      siesta.receive({"geom.fa",
                      "E.total",
                      "MD.Relaxed"})

      local old_image = current_image

      ret_tbl = siesta_move(siesta)

      siesta_update_DM(old_image, current_image)
      siesta_update_xyz(current_image)
      IOprint(NEB[current_image].R)

   end

   siesta.send(ret_tbl)
 end



Double Nudged Elastic Band
..........................

For Using Double Nudged Elastic Band Only difference in Scripts is the initialization of DNEB object, The DNEB initialization is : ::

 local NEB = flos.DNEB(images,{k=k_spring})

Variable Cell Nudged Elastic Band
.................................

Example on how to use an NEB method.

The Initialization is : ::

 local flos = require "flos"
 local image_label = "image_coordinates_"
 local image_vector_label= "image_vectors_"
 local n_images = 5
 local images = {}
 local images_vectors={}
 --local label = "MgO-3x3x1-2V"
 local f_label_xyz = "image_coordinates_"
 local f_label_xyz_vec = "image_vectors_"
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


Some user define functions: ::

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
       return
    end
   local xyz_label = f_label_xyz ..tostring(current)..".xyz"

   local f=io.open(xyz_label,"w")
   f:write(tostring(#NEB[current].R).."\n \n")
   for i=1,#NEB[current].R do
     f:write(string.format(" %19.17f",tostring(NEB[current].R[i][1])).. "   "..string.format("%19.17f",tostring(NEB[current].R[i][2]))..string.format("   %19.17f",tostring(NEB[current].R[i][3])).."\n")
 end
  f:close()
   
 end

 function siesta_update_xyz_vec(current)
   if not siesta.IONode then
       return
    end
   local xyz_vec_label = f_label_xyz_vec ..tostring(current)..".xyz"
   local f=io.open(xyz_vec_label,"w")
   f:write(tostring(#VCNEB[current].R).."\n \n")
   for i=1,#VCNEB[current].R do
     f:write(string.format(" %19.17f",tostring(VCNEB[current].R[i][1])).. "   "..string.format("%19.17f",tostring(VCNEB[current].R[i][2]))..string.format("   %19.17f",tostring(VCNEB[current].R[i][3])).."\n")
  end
 f:close()
  --  
 end

    if not siesta.IONode then
       return
    end
    local DM = label .. ".DM"
    local old_DM = DM .. "." .. tostring(old)
    local current_DM = DM .. "." .. tostring(current)
    local initial_DM = DM .. ".0"
    local final_DM = DM .. ".".. tostring(NEB.n_images+1)
    print ("The Label of Old DM is : " .. old_DM)
    print ("The Label of Current DM is : " .. current_DM)
    if old==0 and current==0 then
      print("Removing DM for Resuming")
      IOprint("Deleting " .. DM .. " for a clean restart...")
      os.execute("rm " .. DM)
    end
 
    if 0 <= old and old <= NEB.n_images+1 and NEB:file_exists(DM) then
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


For the Move Part we have : ::

 function siesta_move(siesta)
   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV
   local E = siesta.E.total / Unit.eV
   NEB[current_image]:set{F=fa, E=E}
   local Vfa = (-flos.Array.from(siesta.geom.stress) * Unit.Ang ^ 3 / Unit.eV)--* vol
   local VE = siesta.E.total / Unit.eV
   VCNEB[current_image]:set{F=Vfa,E=VE}
   if current_image == 0 then
      current_image = NEB.n_images + 1
      siesta.geom.xa = NEB[current_image].R * Unit.Ang
      siesta.geom.cell = VCNEB[current_image].R * Unit.Ang
      IOprint("\nLUA/NEB final state\n")
      IOprint("Lattice Vectors")
      IOprint(VCNEB[current_image].R)
      IOprint("Stresss")
      IOprint(VCNEB[current_image].F)
      return {'geom.xa',"geom.stress","geom.cell"}
   elseif current_image == NEB.n_images + 1 then
      current_image = 1
      siesta.geom.xa = NEB[current_image].R * Unit.Ang
      siesta.geom.cell = VCNEB[current_image].R * Unit.Ang
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, NEB.n_images))
      IOprint("Lattice Vectors")
      IOprint(VCNEB[current_image].R)
      IOprint("Stresss")
      IOprint(VCNEB[current_image].F)
      return {'geom.xa',"geom.stress","geom.cell"}
   elseif current_image < NEB.n_images then
     current_image = current_image + 1
      siesta.geom.xa = NEB[current_image].R * Unit.Ang
      siesta.geom.cell = VCNEB[current_image].R * Unit.Ang
      IOprint(("\nLUA/NEB running NEB image %d / %d\n"):format(current_image, NEB.n_images))
      IOprint("Lattice Vectors")
      IOprint(VCNEB[current_image].R)
      IOprint("Stresss")
      IOprint(VCNEB[current_image].F)
      return {'geom.xa',"geom.stress","geom.cell"}
   end
   local relaxed = true
   local vcrelaxed = true
   local tot_relax= false
   IOprint("\nNEB step")
   local out_R = {}
   local out_VR = {}
   for img = 1, NEB.n_images do
      local F = NEB:force(img, siesta.IONode)
      IOprint("NEB: max F on image ".. img ..
                 (" = %10.5f, climbing = %s"):format(F:norm():max(),
                                                     tostring(NEB:climbing(img))) )
      local all_xa, weight = {}, flos.Array( #relax[img] )
      for i = 1, #relax[img] do
         all_xa[i] = relax[img][i]:optimize(NEB[img].R, F)
         weight[i] = relax[img][i].weight
      end
      weight = weight / weight:sum()
      if #relax[img] > 1 then
         IOprint("\n weighted average for relaxation: ", tostring(weight))
      end
      local out_xa = all_xa[1] * weight[1]
      relaxed = relaxed and relax[img][1]:optimized()
      for i = 2, #relax[img] do
         out_xa = out_xa + all_xa[i] * weight[i]
         relaxed = relaxed and relax[img][i]:optimized()
      end
      local icell = VCNEB[img].R --/ Unit.Ang
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
      local out_vcxa = all_vcxa[1] * vcweight[1]
      vcrelaxed = vcrelaxed and vcrelax[img][1]:optimized()
      for i = 2, #relax[img] do
         out_vcxa = out_vcxa + all_vcxa[i] * vcweight[i]
         vcrelaxed = vcrelaxed and vcrelax[img][i]:optimized()
      end

    all_vcxa = nil   --all_strain = nil
    strain = out_vcxa * stress_mask  --strain = out_strain * stress_mask
    out_vcxa = nil --strain = out_strain * stress_mask --out_strain = nil
    local dcell = flos.Array(icell.shape)
    dcell[1][1]=1.0 + strain[1]
    dcell[1][2]=0.5 * strain[6]
    dcell[1][3]=0.5 * strain[5]
    dcell[2][1]=0.5 * strain[6]
    dcell[2][2]=1.0 + strain[2]
    dcell[2][3]=0.5 * strain[4]
    dcell[3][1]=0.5 * strain[5]
    dcell[3][2]=0.5 * strain[4]
    dcell[3][3]=1.0 + strain[3]
    local out_cell=icell:dot(dcell)
    dcell = nil
    local lat = flos.Lattice:new(icell)
    local fxa = lat:fractional(out_xa)
    xa =fxa:dot(out_cell)
    lat = nil
    fxa = nil
    out_VR[img] = out_cell
    out_R[img] = xa
   end

   NEB:save( siesta.IONode )

   for img = 1, NEB.n_images do
      NEB[img]:set{R=out_R[img]}
      VCNEB[img]:set{R=out_VR[img]}
   end
   current_image = 1
   if relaxed and vcrelaxed then
     tot_relax= true
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

For our main siesta communicator function we have: ::

 function siesta_comm()
   local ret_tbl = {}
   if siesta.state == siesta.INITIALIZE then
      siesta.receive({"Label",
                      "geom.xa",
                      "MD.MaxDispl",
                      "MD.MaxForceTol",
          "MD.MaxStressTol",
          "geom.cell",
          "geom.stress"})
      label = tostring(siesta.Label)
      IOprint("\nLUA NEB calculator")
      for img = 1, NEB.n_images do
         IOprint(("\nLUA NEB relaxation method for image %d:"):format(img))
         for i = 1, #relax[img] do
            relax[img][i].tolerance = siesta.MD.MaxForceTol * Unit.Ang / Unit.eV
            relax[img][i].max_dF = siesta.MD.MaxDispl / Unit.Ang
            vcrelax[img][i].tolerance = siesta.MD.MaxStressTol * Unit.Ang ^ 3 / Unit.eV
            vcrelax[img][i].max_dF = siesta.MD.MaxDispl / Unit.Ang
            if siesta.IONode then
               relax[img][i]:info()
         vcrelax[img][i]:info()
            end
         end
      end
      siesta.geom.xa = NEB.initial.R * Unit.Ang
      siesta.geom.cell = VCNEB.initial.R * Unit.Ang
      IOprint("\nLUA/NEB initial state\n")
      current_image = 0
      siesta_update_DM(0, current_image)
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
      siesta.receive({"geom.fa",
                      "E.total",
                      "MD.Relaxed",
          "geom.cell",
          "geom.stress"})
      local old_image = current_image
      ret_tbl = siesta_move(siesta)
      siesta_update_DM(old_image, current_image)
      siesta_update_xyz(current_image)
      siesta_update_xyz_vec(current_image)
   end
   siesta.send(ret_tbl)
 end


Temperature Dependent Nudged Elastic Band
.........................................

For Using Temperature Nudged Elastic Band Only difference in Scripts is the initialization of TNEB object with Temperature, The TNEB initialization is : ::

 local NEB = flos.TNEB(images,{k=k_spring},neb_temp=300)

where the ``neb_temp`` is in ``K`` .

Force Constants
---------------

This example reads the input options as read by
SIESTA and defines the FC type of run:

 - MD.FCFirst
 - MD.FCLast
 - MD.FCDispl (max-displacement, i.e. for the heaviest atom)

This script will emulate the FC run built-in SIESTA and will only
create the DM file for the first (x0) coordinate.

There are a couple of parameters:

 (1) same_displ = true|false
 if true all displacements will be true, and the algorithm is equivalent
 to the SIESTA FC run.
 If false, the displacements are dependent on the relative masses of the
 atomic species. The given displacement is then the maximum displacement, 
 i.e. the displacement on the heaviest atom.

 (2) displ = {}
 a list of different displacements. If one is interested in several different
 force constant runs with different displacements, this is a simple way
 to do it all at once.

The Initialization is : ::

 local same_displ = true

 local displ = {0.005, 0.01, 0.02, 0.03, 0.04}
 local flos = require "flos"
 local idispl = 1
 local FC = nil
 local Unit = siesta.Units

For the Move Part we have : ::

 function siesta_move(siesta)

   local fa = flos.Array.from(siesta.geom.fa) * Unit.Ang / Unit.eV

   siesta.geom.xa = FC:next(fa) * Unit.Ang
   siesta.MD.Relaxed = FC:done()

   return {"geom.xa",
           "MD.Relaxed"}
 end
      
For our main siesta communicator function we have: ::

 function siesta_comm()
   
   local ret_tbl = {}
   if siesta.state == siesta.INITIALIZE then
      siesta.receive({"geom.xa",
                      "geom.mass",
                      "MD.FC.Displ",
                      "MD.FC.First",
                      "MD.FC.Last"})

      IOprint("\nLUA Using the FC run")
      if displ == nil then
         displ = { siesta.MD.FC.Displ / Unit.Ang }
      end

      local xa = flos.Array.from(siesta.geom.xa) / Unit.Ang
      indices = flos.Array.range(siesta.MD.FC.First, siesta.MD.FC.Last)
      if same_displ then
         FC = flos.ForceHessian(xa, indices, displ[idispl])
      else
         FC = flos.ForceHessian(xa, indices, displ[idispl],
                                siesta.geom.mass)
      end

   end

   if siesta.state == siesta.MOVE then

      siesta.receive({"geom.xa",
                      "geom.fa",
                      "Write.DM",
                      "Write.EndOfCycle.DM",
                      "MD.Relaxed"})

        ret_tbl = siesta_move(siesta)

      siesta.Write.DM = false
      ret_tbl[#ret_tbl+1] = "Write.DM"
      siesta.Write.EndOfCycle.DM = false
      ret_tbl[#ret_tbl+1] = "Write.EndOfCycle.DM"

      FC:save( ("FLOS.FC.%d"):format(idispl) )
      FC:save( ("FLOS.FCSYM.%d"):format(idispl), true )

      if siesta.MD.Relaxed then
         idispl = idispl + 1

         if idispl <= #displ then
            FC:reset()
            FC:set_displacement(displ[idispl])
            siesta.geom.xa = FC:next() * Unit.Ang
            siesta.MD.Relaxed = false

         end

      end

   end

   siesta.send(ret_tbl)
 end


