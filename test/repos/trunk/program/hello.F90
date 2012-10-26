PROGRAM Hello

#if !defined(LOCAL_STRING)
USE Hello_Constants, ONLY: hello_string
#endif

IMPLICIT NONE

#if defined(LOCAL_STRING)
CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Mother Earth!'
#endif

INTEGER :: integer_arg = 1234

#if defined(CALL_HELLO_SUB)
INCLUDE 'hello_sub.interface'
#endif

CHARACTER (LEN=*), PARAMETER :: this = 'Hello'

WRITE (*, '(A)') this // ': ' // TRIM (hello_string)
#if defined(CALL_HELLO_SUB)
CALL Hello_Sub (integer_arg)
#endif

END PROGRAM Hello
