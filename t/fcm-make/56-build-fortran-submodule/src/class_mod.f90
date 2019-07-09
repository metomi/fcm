module class_mod

  implicit none

  type, abstract :: foo_type
    private
    integer :: stuff
  contains
    private
    procedure(mangle_if),   public, deferred :: mangle
    procedure(how_much_if), public, deferred :: how_much
  end type foo_type

  interface
    subroutine mangle_if(this, factor)
      import foo_type
      class(foo_type), intent(inout) :: this
      integer,         intent(in) :: factor
    end subroutine mangle_if
    function how_much_if(this)
      import foo_type
      class(foo_type), intent(inout) :: this
      integer :: how_much_if
    end function how_much_if
  end interface

  type, extends(foo_type) :: bar_type
    private
  contains
    private
    procedure, public :: mangle   => bar_mangle
    procedure, public :: how_much => bar_howmuch
  end type bar_type

  interface bar_type
    procedure bar_initialiser
  end interface bar_type

  interface
    module function bar_initialiser(starter) result(instance)
      integer,intent(in) :: starter
      type(bar_type) :: instance
    end function bar_initialiser
    module subroutine bar_mangle(this, factor)
      class(bar_type), intent(inout) :: this
      integer,         intent(in) :: factor
    end subroutine bar_mangle
    module function bar_howmuch(this)
      class(bar_type), intent(inout) :: this
      integer :: bar_howmuch
    end function bar_howmuch
  end interface

end module class_mod
