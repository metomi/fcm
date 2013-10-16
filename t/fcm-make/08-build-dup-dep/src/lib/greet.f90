subroutine greet(hello, world)
character(*), intent(in) :: hello, world
write(*, '(A,1X,A)') trim(hello), trim(world)
end subroutine greet
