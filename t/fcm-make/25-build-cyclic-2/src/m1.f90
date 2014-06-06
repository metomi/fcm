module m1
character(*), parameter :: WHATEVER
contains
subroutine s1()
write(*, '(a)') f1() // ' from s1'
end subroutine s1
function f1()
use m2, only: HELLO
character(len=len(HELLO)) :: f1
f1 = hello
end function f1
end module m1
