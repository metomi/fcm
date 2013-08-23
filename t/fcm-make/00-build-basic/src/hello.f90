program hello
use world, only: get_world
WRITE(*, '(A,A)') 'Hello ', trim(get_world())
end program hello
