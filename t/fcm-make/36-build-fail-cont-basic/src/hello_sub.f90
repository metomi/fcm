subroutine hello_sub(world)
implicit none
character(*), intent(in) :: world
write(*, '(a)'), 'Hello ' // trim(world)
end subroutine hello_sub
