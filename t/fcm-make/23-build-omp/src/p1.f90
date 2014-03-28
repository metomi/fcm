program p1

!$ use m1, only: s1
!$ use m2, only: s2

    integer, parameter :: n=100
    integer :: i
    real :: x(n), y(n), z(n)

    x(:) = 1.0
    y(:) = 1.0
    z(:) = 1.0
    !$ include "i1.f90"
    !$ include 'i2.f90'
    do i = 1, n
        write(*, '(f3.1)') z(i)
    end do

end program p1
