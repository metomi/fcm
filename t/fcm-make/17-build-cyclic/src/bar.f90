module bar
use quack,  only: quack_type
use baz, only: baz_type
implicit none
private

type, public, abstract, extends(quack_type) :: bar_type
end type
end module bar
