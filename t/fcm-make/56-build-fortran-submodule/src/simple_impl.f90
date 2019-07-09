submodule(simple_mod) simple_impl

  implicit none

contains

  module function returnerer(thing)

    implicit none

    integer, intent(in) :: thing
    integer :: returnerer

    returnerer = 2 * thing

  end function returnerer

end submodule simple_impl
