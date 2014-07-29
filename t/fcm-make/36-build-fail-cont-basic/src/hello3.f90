program hello3
use world_mod, only: world
implicit none
include 'hello_sub.interface'
call hello_sub(world)
end program hello3
