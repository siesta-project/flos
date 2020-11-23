Basic of FLOS
=============


.. figure:: ./_images/2.png
  :width: 400px

  Flos Architecture


Basics
------
How it Works?!
..............

Imagine you have a program which has 3 distinct places where interaction might occur: ::

  program main
  call initialize()
  call calculate()
  call finalize()
  end program 

At each **intermediate point** one wishes to communicate with a scripting language. flook lets you communicate fortran and Lua hence it called Flook=fortran+Lua+hook.

SIESTA Intermediate Points
..........................

When you run SIESTA with FLOOK enabled you have 7 **intermediate point** to communicate:
  (1) Right after reading initial options 
  (2) Right before SCF step starts, but at each MD step
  (3) At the start of each SCF step
  (4) After each SCF has finished
  (5) When moving the atoms, right after the FORCES step
  (6) When SIESTA start Analyse (Post-Processing)
  (7) When SIESTA is complete, just before it exists

We call above **intermediate points** state in lua script you could communicate with SIESTA viastate defination like this: ::

  if siesta.state == siesta.INITIALIZE 
  if siesta.state == siesta.INIT_MD
  if siesta.state == siesta.SCF_LOOP
  if siesta.state == siesta.FORCES
  if siesta.state == siesta.MOVE
  if siesta.state == siesta.ANALYSIS
  if siesta.state == siesta.FINALIZE

How to Communicate with SIESTA
..............................

For Communicate with siesta with it consist of two step :

(1) set these input SIESTA flags in fdf file:
     * set ``MD.TypeOfRun LUA``
     * set ``LUA.Script {NAME OF YOUR SCRIPT}.lua``
(2) Provide the script ``{NAME OF YOUR SCRIPT}.lua`` 

.. NOTE::

  The ``{NAME OF YOUR SCRIPT}.lua`` should be in same folder of ``psf`` & ``fdf`` files.

How to prepare the LUA script for SIESTA
........................................

The SIESTA LUA scripts contains two Parts:

  (1) The Main Siesta Communicator function.
  (2) The user defined specific function.

The Main function contains the **intermediate points** states : ::
  
  function siesta_comm()
    -- Do the actual communication with SIESTA
    
       if siesta.state == siesta.INITIALIZE then
       .
       .
       .
       end

       if siesta.state == siesta.INIT_MD then
       .
       .
       .
       end

       if siesta.state == siesta.SCF_LOOP then
       .
       .
       .
       end 
       
       if siesta.state == siesta.FORCES then   
       .
       .
       .
       end

       if siesta.state == siesta.MOVE then
       .
       .
       .
       end

       if siesta.state == siesta.ANALYSIS then
       .
       .
       .
       end
      
       if siesta.state == siesta.FINALIZE then
       .
       .
       .
       end     
  end

in each part of ``siesta.state`` we could either send or receive data with siesta dictionary. we will discuss that in () section.

The user defined function which is a normal function defined by user for specific task. For instance the above function is counter with a return : ::
  
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

SIESTA LUA Dictionary
.....................

In each **intermediate points** states we could send or receive data via special name we call them SIESTA LUA dictionary. Here we categorized them:

  :slabel:
         SystemLabel
 
  :DM_history_depth:
                   DM.HistoryDepth

  Output Options:

  :dumpcharge:
              Write.DenChar

  :mullipop:
            Write.MullikenPop 
                
  :hirshpop:
           Write.HirshfeldPop

  :voropop:
           Write.VoronoiPop
                     
  SCF Options:

  :min_nscf:
          SCF.MinIterations
  
  :nscf:
       SCF.MaxIterations

  :mixH:
       SCF.MixHamiltonian

  :mix_charge:
             SCF.MixCharge

  :maxsav:
         SCF.NumberPulay

  :broyden_maxit:
                SCF.NumberBroyden

  :wmix:
       SCF.MixingWeight

  :nkick:
        SCF.NumberKick

  :wmixkick:
           SCF.KickMixingWeight
  
  SCF Mixing Options (NEW):

  :scf_mixs(1)%w:
               SCF.Mixer.Weight

  :scf_mixs(1)%restart:
                      SCF.Mixer.Restart

  :scf_mixs(1)%n_itt:
                    SCF.Mixer.Iterations

  :monitor_forces_in_scf:
                        SCF.MonitorForces

  :temp:
       electronicTemperature

  SCF Convergence Criteria:
 
  :converge_Eharr:
                 SCF.Harris.Converge

  :tolerance_Eharr:
                  SCF.Harris.Tolerance

  :converge_DM:
              SCF.DM.Converge

  :dDtol:
        SCF.DM.Tolerance

  :converge_EDM:
               SCF.EDM.Converge

  :tolerance_EDM:
                SCF.EDM.Tolerance

  :converge_H:
             SCF.H.Converge

  :dHtol:
        SCF.H.Tolerance

  :converge_FreeE:
                 SCF.FreeE.Converge

  :tolerance_FreeE:
                  SCF.FreeE.Tolerance

  :dxmax:
        MD.MaxDispl

  :ftol:
       MD.MaxForceTol

  :strtol:
         MD.MaxStressTol

  :ifinal:
         MD.FinalTimeStep

  :dx:
     MD.FC.Displ

  :ia1:
      MD.FC.First

  :ia2:
      MD.FC.Last

  :tt:
     MD.Temperature.Target

  :RelaxCellOnly:
                MD.Relax.CellOnly

  :varcel:MD.MaxDispl
         MD.Relax.Cell

  :inicoor:
          MD.Steps.First

  :fincoor:
          MD.Steps.Last

  :DM_history_depth:
                   MD.DM.History.Depth

  Write Options:

  :saveHS:
         Write.HS

  :writeDM:
          Write.DM
           
  :write_DM_at_end_of_cycle:
                           Write.EndOfCycle.DM

  :writeH:
         Write.H

  :write_H_at_end_of_cycle:
                          Write.EndOfCycle.H

  :writeF:
         Write.Forces

  :UseSaveDM:
            Use.DM

  :hirshpop:
           Write.Hirshfeld

  :voropop:
          Write.Voronoi

  Mesh Options:

  :g2cut:
        Mesh.Cutoff.Minimum

  :saverho:
          Mesh.Write.Rho

  :savedrho:
           Mesh.Write.DeltaRho

  :saverhoxc:
            Mesh.Write.RhoXC

  :savevh:
         Mesh.Write.HartreePotential

  :savevna:
          Mesh.Write.NeutralAtomPotential

  :savevt:
         Mesh.Write.TotalPotential

  :savepsch:
           Mesh.Write.IonicRho

  :savebader:
            Mesh.Write.BaderRho

  :savetoch:
           Mesh.Write.TotalRho

  Geometry Options:

  :na_u:
       geom.na_u

  :ucell:
        geom.cell

  :ucell_last:
             geom.cell_last

  :vcell:
        geom.vcell

  :nsc:
      geom.nsc

  :r2:
     geom.xa

  :r2:
     geom.xa_last

  :va:
     geom.va
  
  Species Options:

  :isa(1:na_u):
              geom.species

  :iza(1:na_u):
              geom.z

  :lasto(1:na_u):
                geom.last_orbital

  :amass:
         geom.mass

  :qa(1:na_u):
             geom.neutral_charge

  :Datm(1:no_u):
               geom.orbital_charge

  Force & Stress Options

  :cfa:
      geom.fa
       
  :fa:
     geom.fa_pristine

  :cfa:
      geom.fa_constrained

  :cstress:
          geom.stress

  :stress:
         geom.stress_pristine

  :cstress:
          geom.stress_constrained

  
  Energies
  
  :DEna:
       E.neutral_atom

  :DUscf:
        E.electrostatic

  :Ef:
     E.fermi

  :Eharrs:
         E.harris

  :Ekin:
        E.kinetic

  :Etot:
       E.total

  :Exc:
      E.exchange_correlation

  :FreeE:
        E.free

  :Ekinion:
          E.ions_kinetic

  :Eions:
        E.ions

  :Ebs:
      E.band_structure

  :Eso:
      E.spin_orbit

  :Eldau:
        E.ldau

  :NEGF_DE:
          E.negf.dN

  :NEGF_Eharrs:
              E.negf.harris

  :NEGF_Etot:
            E.negf.total

  :NEGF_Ekin:
            E.negf.kinetic

  :NEGF_Ebs:
           E.negf.band_structure

  Charges Options:

  :qtot:
       charge.electrons

  :zvaltot:
          charge.protons

  k-point Options

  :kpoint_scf%k_cell:
                    BZ.k.Matrix

  :kpoint_scf%k_displ:
                     BZ.k.Displacement


Now for example if we want to recieve the information of Total Energy we could communicate like this: ::

  siesta.receive({"E.total"})

If we want to send some information to siesta we could communicate like this: ::
  
  siesta.send({"MD.MaxDispl"})












Classes
-------


MDStep
......

The MDStep class retains information on a single MD step. Such a step may be represented by numerous quantities. One may always add new information, but it may for instance be used to retain information such as:
        (1) **R** , the atomic coordinates
        (2) **V** , the velocities
        (3) **F** , the forces
        (4) **E** , an energy associated with the current step.

Array
.....

Array Class is a generic implementation of ND arrays in pure Lua. This module tries to be as similar to the Python numpy package as possible. Due to everything being in Lua there are not *views* of arrays which means that many functions creates unnecessary data-duplications. This may be leveraged in later code implementat ons. The underlying Array class is implemented as follows:

  (1) Every Array gets associated a `Shape` which determines the size of the current Array.
  (2) If the Array is > 1D all elements `Array[i]` is an array with sub-Arrays of one less dimension.
  (3) This enables one to call any Array function on sub-partitions of the Array without having to think about the details.
  (4) The special case is the last dimension which contains the actual data. The `Array` class is using the same names as the Python numerical library `numpy` for clarity.

  
Shape
.....

Implementation of Shape to control the size of arrays (@see Array) @classmod Shape A helper class for managing the size of `Array's`. 

Having the Shape of an array in a separate class makes it much easier to implement a flexible interface for interacting with Arrays. A Shape is basically a table which defines the size of the Array 
the dimensions of the Array is `#Shape` while each axis size may be queried by `Shape[axis]`.
Additionally a Shape may have a single dimension with size `0` which may only be used to align two shapes, i.e. the `0` axis is inferred from the total size of the aligning Shape.

Optimizer
.........

Basic optimization class that is to be inherited by all the optimization classes.

CG
..

An implementation of the conjugate gradient optimization algorithm. This class implements 4 different variations of CG defined by the so-called beta-parameter:

   (1) Polak-Ribiere
   (2) Fletcher-Reeves
   (3) Hestenes-Stiefel
   (4) Dai-Yuan

Additionally this CG implementation defaults to a beta-damping factor to achieve a smooth restart method, instead of abrupt CG restarts when `beta < 0`, for instance.

FIRE
....

The implementation has several options related to the original method.

The `FIRE` optimizer implements several variations of the original FIRE algorithm.

Here we allow to differentiate on how to normalize the displacements:

 (1) `correct` (argument for `FIRE:new`)
 (2) "global" perform a global normalization of the coordinates (maintain displacement direction)
 (3) "local" perform a local normalization (for each direction of each atom) (displacement direction is not maintained)
 (4) `direction` (argument for `FIRE:new`)
 (5) "global" perform a global normalization of the velocities (maintain gradient direction)
 (6)  "local" perform a local normalization of the velocity (for each atom) (gradient direction is not maintained) This `FIRE` optimizer allows two variations of the scaling of the velocities and the resulting displacement.

LBFGS
.....

This class contains implementation of the limited memory BFGS algorithm.
The LBFGS algorithm is a straight-forward optimization algorithm which requires very few arguments for a succesful optimization. The most important parameter is the initial Hessian value, which for large values (close to 1) may have difficulties in converging because it is more aggressive (keeps more of the initial gradient). The default value is rather safe and should enable optimization on most systems. This optimization method also implements a history-discard strategy, if needed, for possible speeding up the convergence. A field in the argument table, `discard`, may be passed which takes one of:

(1) "none", no discard strategy
(2) "max-dF", if a displacement is being made beyond the max-displacement we do not store the   step in the history

This optimization method also implements a scaling strategy, if needed, for possible speeding up the convergence. A field in the argument table, `scaling`, may be passed which takes one of:

(1) "none", no scaling strategy used
(2) "initial", only the initial inverse Hessian and use that in all subsequent iterations
(3) "every", scale for every step

LINE
....

This class conatins implementation of a line minimizer algorithm. The `Line` class optimizes a set of parameters for a function such that the gradient projected onto a gradient-direction will be minimized. I.e. it finds the minimum of a function on a gradient line such that the true gradient is orthogonal to the direction. A simple implementation of a line minimizer. This line-minimization algorithm may use any (default to `LBFGS`) optimizer and will optimize a given direction by projecting the gradient onto an initial gradient direction. 

NEB
...

NEB class Instantiating a new `NEB` object. For the `NEB` object it is important to pass the images, and _then_ all the NEB settings as named arguments in a table.

-- The `NEB` object implements a generic NEB algorithm as detailed in:

(1) "Improved tangent estimate in the nudged elastic band method for finding minimum energy paths and saddle points", Henkelman & Jonsson, JCP (113), 2000
(2)  "A climbing image nudged elastic band method for finding saddle points and minimum energy paths", Henkelman, Uberuaga, & Jonsson, JCP (113), 2000 

.. NOTE::
 This particular implementation has been tested and initially developed by Jesper T. Rasmussen, DTU Nanotech, 2016.

When instantiating a new `NEB` calculator one _must_ populate the initial, all intermediate images and a final image in a a table. The easiest way to do this can be seen in the below usage field. To perform the NEB calculation all images (besides the initial and final) are relaxed by an external relaxation method (see `Optimizer` and its child classes). Due to the forces being highly non-linear as the NEB algorithm updates the forces depending on the nearest images, it is adviced to use an MD-like relaxation method such as `FIRE`. If one uses history based relaxation methods (`LBFGS`, `CG`, etc.) one should limit the number of history steps used. Running the NEB class will create a huge list of files with corresponding output. Check the `NEB:save` function for details.


DNEB
....

A  modification  of  the  nudged  elastic  band NEB method  is  implementation  enables  stable optimizations  to  be  run  using  both  the  limited-memory  Broyden–Fletcher–Goldfarb–Shanno~L-BFGS. quasi-Newton and slow-response quenched velocity Verlet minimizers. The DNEB bject implements a generic DNEB algorithm as detailed in: 

- "A doubly nudged elastic band method for finding transition states", Semen A. Trygubenkoa and David J. Wales , J. Chem. Phys., Vol. 120, No. 5, 1 February 2004.


VCNEB
.....
The VC-NEB method is a more general tool for exploring the activation paths between the two end points of a phase transition process within a larger configuration space. The VC-NEB object implements a generic VC-NEB algorithm as detailed in:

- "Variable cell nudged elastic band method for studying solid–solid structural phase transitions" ,G.-R.Qianetal, Computer Physics Communications 184 (2013) 2111–2118.

TNEB
....

TNEB is a  method  to  introduce  temperature  corrections  to  a  minimum-energyreaction path. The method is based on the maximization of the flux for the Smoluchowski equationand it is implemented using a nudged-elastic-band algorithm. 

The TNEB object implements a generic TNEB algorithm as detailed in:

- "A temperature-dependent nudged-elastic-band algorithm", Ramon Crehuet and Martin J. Field,The Journal of Chemical Physics 118, 9563 (2003); doi: 10.1063/1.1571817

 
