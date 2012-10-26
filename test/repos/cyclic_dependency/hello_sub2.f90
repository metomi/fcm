SUBROUTINE Hello_Sub2 (integer_arg)

IMPLICIT NONE

INTEGER :: integer_arg

INCLUDE 'hello_sub.interface'

CALL Hello_Sub (integer_arg)

END SUBROUTINE Hello_Sub2
