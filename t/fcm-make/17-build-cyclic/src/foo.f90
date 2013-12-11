module foo
use bar, only: bar_type
use baz, only: baz_type
implicit none
private

type, public, extends(bar_type) :: foo_type
end type

end module foo
