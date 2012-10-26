! A simple function
logical function func_simple()
func_simple = .true.
end function func_simple

! A simple function, but with less friendly end
logical function func_simple_1()
func_simple_1 = .true.
end function

! A simple function, but with even less friendly end
logical function func_simple_2()
func_simple_2 = .true.
end

! A pure simple function
pure logical function func_simple_pure()
func_simple_pure = .true.
end function func_simple_pure

! A pure recursive function
recursive pure integer function func_simple_recursive_pure(i)
integer, intent(in) :: i
if (i <= 0) then
    func_simple_recursive_pure = i
else
    func_simple_recursive_pure = i + func_simple_recursive_pure(i - 1)
end if
end function func_simple_recursive_pure

! An elemental simple function
elemental logical function func_simple_elemental()
func_simple_elemental = .true.
end function func_simple_elemental

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

! An function with arguments and module imports
integer(selected_int_kind(0)) function func_with_use_and_args(egg, ham)
use foo
! Deliberate trailing spaces in next line
use bar, only : organic,     i_am_dim   
implicit none
integer, intent(in) :: egg(i_am_dim)
integer, intent(in) :: ham(i_am_dim, 2)
real bacon
! Deliberate trailing spaces in next line
type(   organic   ) :: tomato   
func_with_use_and_args = egg(1) + ham(1, 1)
end function func_with_use_and_args

! A function with some parameters
character(20) function func_with_parameters(egg, ham)
implicit none
character*(*), parameter :: x_param = '01234567890'
character(*), parameter :: & ! throw in some comments
    y_param                &
    = '!&!&!&!&!&!'          ! how to make life interesting
integer, parameter :: z = 20
character(len(x_param)), intent(in) :: egg
character(len(y_param)), intent(in) :: ham
func_with_parameters = egg // ham
end function func_with_parameters

! A function with some parameters, with a result
function func_with_parameters_1(egg, ham) result(r)
implicit none
integer, parameter :: x_param = 10
integer z_param
parameter(z_param = 2)
real, intent(in), dimension(x_param) :: egg
integer, intent(in) :: ham
logical :: r(z_param)
r(1) = int(egg(1)) + ham > 0
r(2) = .false.
end function func_with_parameters_1

! A function with a contains
character(10) function func_with_contains(mushroom, tomoato)
character(5) mushroom
character(5) tomoato
func_with_contains = func_with_contains_1()
contains
character(10) function func_with_contains_1()
func_with_contains_1 = mushroom // tomoato
end function func_with_contains_1
end function func_with_contains

! A function with its result declared after a local in the same statement
Function func_mix_local_and_result(egg, ham, bacon) Result(Breakfast)
Integer, Intent(in) :: egg, ham
Real, Intent(in) :: bacon
Real :: tomato, breakfast
Breakfast = real(egg) + real(ham) + bacon
End Function func_mix_local_and_result

! A simple subroutine
subroutine sub_simple()
end subroutine sub_simple

! A simple subroutine, with not so friendly end
subroutine sub_simple_1()
end subroutine

! A simple subroutine, with even less friendly end
subroutine sub_simple_2()
end

! A simple subroutine, with funny continuation
subroutine sub_simple_3()
end sub&
&routine&
& sub_simple_3

! A subroutine with a few contains
subroutine sub_with_contains(foo) ! " &
! Deliberate trailing spaces in next line
use Bar, only: i_am_dim    
character*(len('!"&''&"!')) & ! what a mess!
    foo
call sub_with_contains_first()
call sub_with_contains_second()
call sub_with_contains_third()
print*, foo
contains
subroutine sub_with_contains_first()
interface
integer function x()
end function x
end interface
end subroutine sub_with_contains_first
subroutine sub_with_contains_second()
end subroutine
subroutine sub_with_contains_third()
end subroutine
end subroutine sub_with_contains

! A subroutine with a renamed module import
subroutine sub_with_renamed_import(i_am_dim)
use bar, only: i_am_not_dim => i_am_dim
integer, parameter :: d = 2
complex :: i_am_dim(d)
print*, i_am_dim
end subroutine sub_with_renamed_import

! A subroutine with an external argument
subroutine sub_with_external(proc)
external proc
call proc()
end subroutine sub_with_external

! A subroutine with a variable named "end"
subroutine sub_with_end()
integer :: end
end = 0
end subroutine sub_with_end
