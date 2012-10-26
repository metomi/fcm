MODULE hello_number

IMPLICIT NONE

PRIVATE
INTEGER, PARAMETER :: i=0
INTEGER, PARAMETER :: huge_number=HUGE(i)

PUBLIC hello_huge_number

CONTAINS
SUBROUTINE hello_huge_number()
CHARACTER(LEN=*), PARAMETER :: this='hello_huge_number'
WRITE(*, '(A,I0)') this // ': maximum integer: ', huge_number
END SUBROUTINE hello_huge_number

END MODULE hello_number
