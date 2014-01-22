program greet
implicit none
include 'hello.interface'
include 'hi.interface'
abstract interface
subroutine abstract_greet()
end subroutine abstract_greet
end interface
procedure(abstract_greet), pointer :: say
say => hello
call say()
say => hi
call say()
end program greet
