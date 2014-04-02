module m2
contains
subroutine s2(n, z, y)
integer, intent(in) :: n
real, intent(out) :: z(:)
real, intent(in) :: y(:)
integer :: i
!$omp parallel do shared(z)
do i = 1, n
z(i) = y(i) * 3.0
end do
!$omp end parallel do
end subroutine s2
end module m2
