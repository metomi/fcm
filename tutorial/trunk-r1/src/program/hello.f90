PROGRAM hello

USE Hello_Constants, ONLY: hello_string

IMPLICIT NONE
INCLUDE 'hello_sub.interface'
CHARACTER(*), PARAMETER :: this='hello'

WRITE(*, '(A)') this // ': ' // TRIM(hello_string)
CALL Hello_Sub()

END PROGRAM hello
