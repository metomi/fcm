program hello
use greet_mod, only: greet
use world_mod, only: world
implicit none
call greet(world)
end program hello
