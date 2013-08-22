#if defined(HELLO_SUB)
SUBROUTINE Hello_Sub (integer_arg)

USE Hello_Constants, ONLY: hello_string

IMPLICIT NONE

CHARACTER (LEN=*), PARAMETER :: this = 'Hello_Sub'
INTEGER :: integer_arg
INTEGER :: integer_common
COMMON /general/integer_common

! DEPENDS ON: hello_c.o
EXTERNAL Hello_C

#include "hello_sub_dummy.h"

WRITE (*, '(A,I0)') this // ': integer (arg): ', integer_arg
WRITE (*, '(A,I0)') this // ': integer (common): ', integer_common

CALL Hello_C ()

END SUBROUTINE Hello_Sub
#endif
