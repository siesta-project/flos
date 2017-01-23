
-- Definitions local classes used in this project
local mc = require "middleclass.middleclass"

local Array = mc.class('Array')
local Array1D = mc.class("Array1D", Array)
local Array2D = mc.class("Array2D", Array)

local istable = function (obj)
   return type(obj) == "table"
end

local instanceOf = function (obj, class)
   if istable(obj) then
      if obj.class then
	 return obj:isInstanceOf(class)
      end
   end
   return false
end

local subclassOf = function (obj, class)
   if istable(obj) then
      if obj.class then
	 return obj:isSubclassOf(class)
      end
   end
   return false
end

return {
   -- Class-determination methods
   ['istable'] = istable,
   ['instanceOf'] = instanceOf,
   ['subclassOf'] = subclassOf,
   -- Classes
   ['Array'] = Array,
   ['Array1D'] = Array1D,
   ['Array2D'] = Array2D,
}
