Setting Up FLOS
===============

Requirements
------------
The only requirement is the Lua language.
The require Lua version is 5.3. However, if you are stuck with Lua 5.2 you can apply this patch ::

  patch -p1 < lua_52.patch

Installation
------------

This Lua library may be used out of the box. To enable the use of this library you only require the LUA_PATH to contain the path to the library. 
Importantly this library requires an explicit <path>/?/init.lua definition.

As an example the following bash commands enables the library ::

  cd $HOME
  git clone https://github.com/siesta-project/flos.git
  cd flos
  git submodule init
  git submodule update
  export LUA_PATH="$HOME/flos/?.lua;$HOME/flos/?/init.lua;$LUA_PATH;;"

and that is it. Now you can use the flos library.

