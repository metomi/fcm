module m2
use m1, only: WHATEVER
character(*), parameter :: HELLO='Hello'
contains
subroutine s2()
write(*, '(a)') HELLO // ' from s2'
end subroutine s2
end module m2
