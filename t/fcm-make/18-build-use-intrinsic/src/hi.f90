subroutine hi()
use, intrinsic :: iso_fortran_env !, only: output_unit
write(output_unit, '(a)') 'Hi'
end subroutine hi
