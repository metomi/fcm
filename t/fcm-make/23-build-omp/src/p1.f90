program p1

!$ use omp_lib
!$ use m1, only: s1

integer, parameter :: n=100
integer :: i
real :: x(n), y(n), z(n)

include 's3.interface'

x(:) = 1.0
y(:) = 1.0
z(:) = 1.0
!$ include "i1.f90"
call s3(n, z, y)
do i = 1, n
    write(*, '(f3.1)') z(i)
end do

end program p1
