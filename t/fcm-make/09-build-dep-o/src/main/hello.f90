program hello
character(5) :: w
interface
subroutine greet(hi, world)
character(*), intent(in) :: hi, world
end subroutine greet
subroutine world(w)
character(*), intent(out) :: w
end subroutine world
end interface
call world(w)
call greet('Hello', w)
end program hello
