
local array = require "flos.array"

v1 = array.Array1D.empty(6)
print(#v1)
for i = 1, #v1 do
   v1[i] = i
end
print(v1)

v2 = array.Array2D.empty(6, 6)
k = 0
for i = 1, #v2 do
   for j = 1, #v2[i] do
      v2[i][j] = i * j + k
   end
   k = k + 1
end
print(v2)

print('Array1D dot Array1D')
print(v1:dot(v1))

print('Array2D dot Array1D')
print(v2:dot(v1))

print('Array1D dot Array2D')
print(v1:dot(v2))

print('Array2D ^ T')
print(v2 ^ "T")


print('Array1D: reshaping, explicit')
print(#v1, v1:reshape(-1).size)

print('Array1D: reshaping, implicit')
print(#v1, v1:reshape().size)

print('Array1D: reshaping, other')
print(#v1, v1:reshape(2, -1).size)

print('Array1D: reshaping, other')
print(#v1, v1:reshape(-1, 2).size)

print('Array2D: reshaping, explicit')
print(v2.size, v2:reshape(-1).size)

print('Array2D: reshaping, implicit')
print(v2.size, v2:reshape().size)

print('Array2D: reshaping, other')
print(v2.size, v2:reshape(12, -1).size)

print('Array2D: reshaping, other')
print(v2.size, v2:reshape(-1, 12).size)

print('Array1D: range')
print(array.Array1D.range(1, -34, -3))
