Setting Up FLOS for SIESTA
==========================
Requirements
------------
The only requirement is the Lua language.
The require Lua version is 5.3. However, if you are stuck with Lua 5.2 you can apply this patch ::

  patch -p1 < lua_52.patch

.. NOTE:: 

  For sure running siesta with lua needs the compilation of siesta with flook library, which enabling the fortran lua hook (flook) that we will discusse () section. 


Installation of flos
--------------------

This Lua library may be used out of the box. To enable the use of this library you only require the LUA_PATH to contain the path to the library. 
Importantly this library requires an explicit <path>/?/init.lua definition. As an example the following bash commands enables the library ::

  cd $HOME
  git clone https://github.com/siesta-project/flos.git
  cd flos
  git submodule init
  git submodule update
  export LUA_PATH="$HOME/flos/?.lua;$HOME/flos/?/init.lua;$LUA_PATH;;"

and that is it. Now you can use the flos library.


Enabling SIESTA LUA interface (FLOOK)
-------------------------------------
As we mentioned we have to compile siesta with flook library. 
Downloading and installation
............................
Installing flook requires you to first fetch the library which is currently hosted at github at flook.
To fetch all required files do this: ::
  git clone https://github.com/ElectronicStructureLibrary/flook.git
  cd flook
  git submodule init
  git submodule update
now depending of compiler Vendor you have to options:
* gfortran
* ifort

To compile with gfortran do this: ::
  make VENDOR=gfortran
  make liball VENDOR=gfortran
To compile with ifort do this: ::
  make VENDOR=intel
  make liball VENDOR=intel

After compiling you we have above libs which needed for compiling siesta: ::
 flook.mod
 libflook.a
 libflookall.a
 

