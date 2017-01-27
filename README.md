# sfl

This library enables optimization schemes created in Lua to be
used together with [SIESTA][siesta].

This enables scripting level languages to inter-act and develop
new MD schemes, such as new geometry constraints, geometry relaxations, etc.

## Installation

This Lua library may be used out of the box. To enable the use of this library
you only require the `LUA_PATH` to contain the path to the library.  
Importantly this library requires an explicit `<path>/?/init.lua` definition.

As an example the following bash commands enables the library:

    cd $HOME
    git clone git@github.com:siesta-project/siesta-sfl.git
	git submodule init
	git submodule update
	export LUA_PATH="$HOME/siesta-sfl/?.lua;$HOME/siesta-sfl/?/init.lua;$LUA_PATH"

and that is it. Now you can use the `sfl` library.
    

## Basic usage

To enable this library you should add this to your Lua script:

    local sfl = require "sfl"

which enables you to interact with all implemented `sfl` implemented algorithms.


## Usage in SIESTA

In principle `sfl` is not relying on the [SIESTA][siesta] routines and may
be used as a regular Lua library, although it has been developed
with [SIESTA][siesta] in mind.

In the `examples/` folder there are 3 examples which:

1. Relax the atomic coordinates using the L-BFGS algorithm (`relax_geometry.lua`)
2. Relax the cell vectors using the L-BFGS algorithm (`relax_cell.lua`)
3. Relax the cell vectors and the atomic coordinates using the L-BFGS algorithm (`relax_cell_geometry.lua`)

In order to use any of these schemes you simply need to follow these steps:

1. Compile `flook`, see this page: [`flook`][flook]
2. Compile [SIESTA][siesta] with `flook` support. If you have followed the
   procedure outlined [here][flook] you should add this to the SIESTA `arch.make`:

        FLOOK_PATH  = /path/to/flook/parent
        FLOOK_LIBS  = -L$(FLOOK_PATH)/src -lflookall -ldl
        FLOOK_INC   = -I$(FLOOK_PATH)/src
        INCFLAGS += $(FLOOK_INC)
        LIBS += $(FLOOK_LIBS)
	    FPPFLAGS += -DSIESTA__FLOOK

3. Then you have, for good, enabled the Lua hook.  
   To enable Lua in SIESTA simply set these fdf-flags:

        MD.TypeOfRun lua
        LUA.Script <script-name>

For instance to use the `sfl` relaxation method:

    cp siesta-sfl/examples/relax_geometry.lua <path-to-siesta-run>/relax.lua

and the fdf-flag should be:

    LUA.Script relax.lua

Now run SIESTA.


[flook]: https://github.com/ElectronicStructureLibrary/flook
[siesta]: https://launchpad.net/siesta
