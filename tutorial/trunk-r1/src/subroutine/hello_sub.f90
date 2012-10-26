SUBROUTINE hello_sub

USE hello_constants, ONLY: hello_string
USE hello_number, ONLY: hello_huge_number

IMPLICIT NONE
CHARACTER(*), PARAMETER :: this = 'hello_sub'
! DEPENDS ON: hello_c.o
EXTERNAL hello_c

WRITE(*, '(A)') this // ': ' // TRIM(hello_string)
CALL hello_huge_number()
CALL hello_c()

END SUBROUTINE hello_sub
