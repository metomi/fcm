module m1
contains
subroutine s1(n, y, x)
integer, intent(in) :: n
real, intent(out) :: y(:)
real, intent(in) :: x(:)
integer :: i
!$omp parallel do shared(y)
do i = 1, n
y(i) = x(i) * 2.0
end do
!$omp end parallel do
end subroutine s1
end module m1
