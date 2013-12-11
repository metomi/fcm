program hello 
  use foo, only: foo_type
  use meow, only: meow_type
  use baz, only: baz_type
  implicit none
  write(*, '(A)') 'Hello'
end program hello
