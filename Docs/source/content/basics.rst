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

At each intermediate point one wishes to communicate with a scripting language. flook lets you communicate fortran and Lua hence it called Flook=fortran+Lua+hook.

SIESTA Intermediate Points
..........................

When you run SIESTA with FLOOK enabled you have 6 intermediate point to communicate: 
  (1) Right after reading initial options 
  (2) Right before SCF step starts, but at each MD step
  (3) At the start of each SCF step
  (4) After each SCF has finished
  (5) When moving the atoms, right after the FORCES step
  (6) When SIESTA is complete, just before it exists

We call above intermediate points state in lua script you could communicate with SIESTA viastate defination like this: ::

  if siesta.state == siesta.INITIALIZE 
 















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

