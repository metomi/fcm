subroutine hello_sub
use hello_mod, only: greet
write(*, '(a,1x,a)') greet, 'world'
end subroutine hello_sub
