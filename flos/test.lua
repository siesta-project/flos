
local array = require "flos.array"

v1 = array.Array1D:new(5)
for i = 1, #v1 do
   v1[i] = i
end
print(v1)

v2 = array.Array2D:new(5, 5)
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


print('Array2D: reshaping')
print(v2:reshape(-1))

print('Array1D: range')
print(array.Array1D.range(1, -34, -3))
