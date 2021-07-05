.. flos-documentation documentation master file, created by
   sphinx-quickstart on Sun Jan 26 19:32:11 2020.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to flos-documentations!
==============================================
SIESTA (Spanish Initiative for Electronic Simulations with Thousands of Atoms) is one of the main ICN2's/ICMAB's simulation software. Co-authored by members of these labs, this package allows to run Densisty Functional Theory (DFT) calculations to simulate atomic-scale structures, molecules, materials, and nanodevices. This page is a technical guide on how to set up and run SIESTA-LUA on the HPCCM. It is not meant to describe the underlying theory: information about the mathematical and physical foundations of SIESTA can be found on the official documentation. By embedding Lua in existing fortran codes, one can exchange information from powerful DFT software “SIESTA” with scripting languages such as Lua. By abstracting the interface in fortran one can easily generalize a communication layer to facilitate on-the-fly interaction with the program. To do so we can compile the siesta with the fortran-Lua-hook library “flook”. Its main usage is the ability to change run-time variables at run-time in order to optimize, or even change, the execution path of the parent program. One of the library for which developed for siesta is the “flos” (flook+siesta). This library enables optimization schemes created in Lua to be used together with SIESTA via the flook library, hence the same flo+SIESTA=FLOS. This enables scripting level languages to inter-act and develop new MD schemes, such as new geometry constraints, geometry relaxations, Nudged Elastic Band (NEB),etc.



.. toctree::
   :maxdepth: 2
   :caption: Contents:



Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
