module simple_mod

  implicit none

  interface
    module function returnerer(thing)
      implicit none
      integer, intent(in) :: thing
      integer :: returnerer
    end function returnerer
  end interface

end module simple_mod
