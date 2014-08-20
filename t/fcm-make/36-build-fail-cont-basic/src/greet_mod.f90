module greet_mod
implicit none
character(*), parameter :: greet_word = 'Hello'
contains
subroutine greet(world)
character(*), intent(in) :: world
write(*, '(a,1x,a)') greet_word, world
end subroutine greet
end module greet_mod
