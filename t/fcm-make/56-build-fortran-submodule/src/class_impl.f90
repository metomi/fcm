submodule(class_mod) class_impl

  implicit none

contains

  module function bar_initialiser( starter ) result(instance)
    implicit none
    integer, intent(in) :: starter
    type(bar_type) :: instance
    instance%stuff = starter
  end function bar_initialiser


  module subroutine bar_mangle(this, factor)
    implicit none
    class(bar_type), intent(inout) :: this
    integer,         intent(in)    :: factor
    this%stuff = ieor(this%stuff, factor)
  end subroutine bar_mangle


  module procedure bar_howmuch ! Alternative syntax
    bar_howmuch = this%stuff
  end procedure bar_howmuch

end submodule class_impl
