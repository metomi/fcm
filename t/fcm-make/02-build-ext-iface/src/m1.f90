! A module with nonsense
module bar
type food
integer :: cooking_method
end type food
type organic
integer :: growing_method
end type organic
integer, parameter :: i_am_dim = 10
end module bar

! A module with more nonsense
module foo
use bar, only: FOOD
integer :: foo_int
contains
subroutine foo_sub(egg)
integer, parameter :: egg_dim = 10
type(Food), intent(in) :: egg
write(*, *) egg
end subroutine foo_sub
elemental function foo_func() result(f)
integer :: f
f = 0
end function
end module foo
