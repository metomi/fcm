PROGRAM Hello

USE Hello_Constants, ONLY: hello_string, Hello_Sub_Wrapper

IMPLICIT NONE

INTEGER :: integer_arg = 1234

CHARACTER (LEN=*), PARAMETER :: this = 'Hello'

WRITE (*, '(A)') this // ': ' // TRIM (hello_string)
CALL Hello_Sub_Wrapper (integer_arg)

END PROGRAM Hello
