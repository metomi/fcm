module world
include 'worldx.f90'
contains
elemental function get_world() result(w)
character(len=len(world1)) :: w
w = world1
end function get_world
end module world
