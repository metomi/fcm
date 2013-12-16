module meow
use quack,  only: quack_type
use baz, only: baz_type
use foo,      only: foo_type
implicit none
private

type, public, extends(baz_type) :: meow_type
end type

end module meow
