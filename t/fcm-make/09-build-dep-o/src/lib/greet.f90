subroutine greet(hello, world)
use greet_fmt_mod, only: greet_fmt
character(*), intent(in) :: hello, world
write(*, greet_fmt) trim(hello), trim(world)
end subroutine greet
