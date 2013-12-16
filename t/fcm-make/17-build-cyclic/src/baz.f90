module baz
use quack, only: quack_type
use bar, only: bar_type
implicit none
private

type, public, abstract :: baz_type
end type

end module baz
