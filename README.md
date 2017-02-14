# flos

This library enables optimization schemes created in Lua to be
used together with [SIESTA][siesta] via the [flook][flook] library, hence
the same `flo + SIESTA = flos`.

This enables scripting level languages to inter-act and develop
new MD schemes, such as new geometry constraints, geometry relaxations, etc.

## Installation

This Lua library may be used out of the box. To enable the use of this library
you only require the `LUA_PATH` to contain the path to the library.  
Importantly this library requires an explicit `<path>/?/init.lua` definition.

As an example the following bash commands enables the library:

    cd $HOME
    git clone https://github.com/siesta-project/flos.git
	cd flos
	git submodule init
	git submodule update
	export LUA_PATH="$HOME/flos/?.lua;$HOME/flos/?/init.lua;$LUA_PATH"

and that is it. Now you can use the `flos` library.
    

## Basic usage

To enable this library you should add this to your Lua script:

    local flos = require "flos"

which enables you to interact with all implemented `flos` implemented algorithms.


## Usage in SIESTA

In principle `flos` is not relying on the [SIESTA][siesta] routines and may
be used as a regular Lua library, although it has been developed
with [SIESTA][siesta] in mind.

In the `examples/` folder there are several examples which may be directly used in _any_
[SIESTA][siesta] run for relaxation (they are generalized for any structure).

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

3. Then you have, for good (contrary to the `constr` routine in SIESTA), 
   enabled the Lua hook and you may exchange Lua scripts with other users
   and use scripts as you please.  
   To enable Lua in SIESTA simply set these fdf-flags:

        MD.TypeOfRun lua
        LUA.Script <script-name>

For instance to use the `flos` L-BFGS relaxation method:

    cp flos/examples/relax_geometry_lbfgs.lua <path-to-siesta-run>/relax.lua

and set the following fdf-flag:

    MD.TypeOfRun LUA
    LUA.Script relax.lua

Now run SIESTA.


[flook]: https://github.com/ElectronicStructureLibrary/flook
[siesta]: https://launchpad.net/siesta
