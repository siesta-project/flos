
-- Error messages...

-- The regular floserr which instantiates a traceback
local floserr = function(msg)
   -- Print out a stack-trace without this function call
   print(debug.traceback(nil, 2))
   error(msg)
end

return {
   ['floserr'] = floserr,
}
