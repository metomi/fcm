#!/bin/sh

echo "### Fortran compiler tests"
for fc in \
  "ifort" \
  "ifort -assume nosource_include" \
  "gfortran" \
  "gfortran -I-"
do
  echo
  echo "Compiler: $fc"
  echo "Fortran include test:"
  $fc -o test.o -I$PWD/inc -c prog/test_fortran_inc.f90
  $fc -o test.exe test.o
  test.exe
  rm test.exe test.o
  echo "CPP include test:"
  $fc -o test.o -I$PWD/inc -c prog/test_prepro_inc.F90
  $fc -o test.exe test.o
  test.exe
  rm test.exe test.o
done

echo
echo "### Preprocessor tests"
fc=gfortran
for cpp in \
  "cpp -P -traditional" \
  "cpp -P -traditional -I-"
do
  echo
  echo "Pre-processor: $cpp"
  $cpp -I$PWD/inc prog/test_prepro_inc.F90 >tmp.f90
  $fc -o test.o -I$PWD/inc -c tmp.f90
  $fc -o test.exe test.o
  test.exe
  rm test.exe test.o tmp.f90
done
