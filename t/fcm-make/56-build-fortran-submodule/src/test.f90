program test

  use iso_fortran_env, only : output_unit

  use class_mod,  only : bar_type
  use simple_mod, only : returnerer

  implicit none

  type(bar_type) :: thing

  thing = bar_type(12)

  write(output_unit, '("Returner ", I0)') returnerer(7)
  write(output_unit, '()')

  write(output_unit, '("Start with ", I0)') thing%how_much()
  call thing%mangle(17)
  write(output_unit, '("After mangle ", I0)') thing%how_much()

end program test
