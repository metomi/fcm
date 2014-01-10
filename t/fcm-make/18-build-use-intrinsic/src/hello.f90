subroutine hello()
use, intrinsic :: iso_fortran_env, only: output_unit
write(output_unit, '(a)') 'Hello'
end subroutine hello
