Tutorials of FLOS
=================

Optimizations
-------------

Mech Cutoff
...........

This tutorial can take any system and will perform a series of calculations with increasing
Mesh.Cutoff and it will write-out a table file to be plotted which contains the Mesh.Cutoff vs Energu.

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


Relaxations
-----------

Geometry Relaxation
...................

Geometry and Cell Relaxation
............................


Relaxation with CG
..................


Relaxation with Fire
....................


Relaxation with LBFGS
.....................


Constrained Relaxation
......................


Finding Transition States Minimum Energy Path (MEP)
---------------------------------------------------

Nudged Elastic Band
...................


Double Nudged Elastic Band
..........................


Variable Cell Nudged Elastic Band
.................................


Force Constants
---------------






