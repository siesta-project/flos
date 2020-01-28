Basic of FLOS
=============
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

When you run SIESTA with FLOOK enabled you have 6 **intermediate point** to communicate:
  (1) Right after reading initial options 
  (2) Right before SCF step starts, but at each MD step
  (3) At the start of each SCF step
  (4) After each SCF has finished
  (5) When moving the atoms, right after the FORCES step
  (6) When SIESTA is complete, just before it exists

We call above **intermediate points** state in lua script you could communicate with SIESTA viastate defination like this: ::

  if siesta.state == siesta.INITIALIZE 
  if siesta.satte == siesta.INIT_MD
  if siesta.satte == siesta.SCF_LOOP
  if siesta.satte == siesta.FORCES
  if siesta.satte == siesta.MOVE
  if siesta.satte == siesta.ANALYSIS


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

       if siesta.satte == siesta.INIT_MD then
       .
       .
       .
       end

       if siesta.satte == siesta.SCF_LOOP then
       .
       .
       .
       end 
       
       if siesta.satte == siesta.FORCES then   
       .
       .
       .
       end

       if siesta.satte == siesta.MOVE then
       .
       .
       .
       end

       if siesta.satte == siesta.ANALYSIS then
       .
       .
       .
       end
  end

in each part of ``siesta.state`` we could either send or recieve data. we will discuss that in () section.











Classes
-------


MDStep
......

Array
.....

Shape
.....

Optimizer
.........

CG
..

FIRE
....

LBFGS
.....

LINE
....

NEB
...

VCNEB
.....

DNEB
....

