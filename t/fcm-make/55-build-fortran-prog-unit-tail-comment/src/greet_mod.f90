module greet_mod ! a greeting module for testing
contains
subroutine greet_world()
write(*, '(a)') 'Greet World'
end subroutine greet_world
end module greet_mod ! world does not end here
