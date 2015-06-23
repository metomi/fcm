program hello
character(31) :: world = 'World'
namelist /world_nl/ world
read(*, nml=world_nl)
write(*, '(a,1x,a)') 'Hello', trim(world)
end program hello
