PROGRAM Hello

#if !defined(LOCAL_STRING)
USE Hello_Constants, ONLY: hello_string
#endif

IMPLICIT NONE

#if defined(LOCAL_STRING)
CHARACTER (LEN=80), PARAMETER :: hello_string = 'Hello Mother Earth!'
#endif

#if defined(CALL_HELLO_SUB)
INCLUDE 'hello_sub.interface'
#endif
INCLUDE 'hello_sub2.interface'

CHARACTER (LEN=*), PARAMETER :: this = 'Hello'

WRITE (*, '(A)') this // ': ' // TRIM (hello_string)
#if defined(CALL_HELLO_SUB)
CALL Hello_Sub (HUGE(0))
#endif
CALL Hello_Sub2 ()

END PROGRAM Hello
