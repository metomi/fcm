interface
logical function func_simple()
end function func_simple
logical function func_simple_1()
end function
logical function func_simple_2()
end
pure logical function func_simple_pure()
end function func_simple_pure
recursive pure integer function func_simple_recursive_pure(i)
integer, intent(in) :: i
end function func_simple_recursive_pure
elemental logical function func_simple_elemental()
end function func_simple_elemental
integer(selected_int_kind(0)) function func_with_use_and_args(egg, ham)
use foo
use bar, only:&
 & i_am_dim
integer, intent(in) :: egg(i_am_dim)
integer, intent(in) :: ham(i_am_dim, 2)
end function func_with_use_and_args
character(20) function func_with_parameters(egg, ham)
character*(*), parameter :: x_param = '01234567890'
character(*), parameter :: &
 y_param &
 = '!&!&!&!&!&!'
character(len(x_param)), intent(in) :: egg
character(len(y_param)), intent(in) :: ham
end function func_with_parameters
function func_with_parameters_1(egg, ham) result(r)
integer, parameter :: x_param = 10
integer z_param
parameter(z_param = 2)
real, intent(in), dimension(x_param) :: egg
integer, intent(in) :: ham
logical :: r(z_param)
end function func_with_parameters_1
character(10) function func_with_contains(mushroom, tomoato)
character(5) mushroom
character(5) tomoato
end function func_with_contains
Function func_mix_local_and_result(egg, ham, bacon) Result(Breakfast)
Integer, Intent(in) :: egg, ham
Real, Intent(in) :: bacon
Real :: tomato, breakfast
End Function func_mix_local_and_result
subroutine sub_simple()
end subroutine sub_simple
subroutine sub_simple_1()
end subroutine
subroutine sub_simple_2()
end
subroutine sub_simple_3()
end sub&
&routine&
& sub_simple_3
subroutine sub_with_contains(foo)
character*(len('!"&''&"!')) &
 foo
end subroutine sub_with_contains
subroutine sub_with_renamed_import(i_am_dim)
integer, parameter :: d = 2
complex :: i_am_dim(d)
end subroutine sub_with_renamed_import
subroutine sub_with_external(proc)
external proc
end subroutine sub_with_external
subroutine sub_with_end()
end subroutine sub_with_end
end interface
