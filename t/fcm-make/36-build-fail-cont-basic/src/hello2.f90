program hello2
use greet_mod, only: greet
use world_mod, only: world
implicit none
call greet(trim(world))
end program hello2
