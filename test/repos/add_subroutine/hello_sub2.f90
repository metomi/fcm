SUBROUTINE Hello_Sub2

USE Hello_Constants, ONLY: hello_string

IMPLICIT NONE

CHARACTER (LEN=*), PARAMETER :: this = 'Hello_Sub2'

WRITE (*, '(A)') this // ': ' // TRIM (hello_string)

END SUBROUTINE Hello_Sub2
