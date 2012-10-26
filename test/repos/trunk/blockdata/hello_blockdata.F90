BLOCK DATA hello_blockdata
INTEGER :: integer_common
COMMON /general/integer_common
#if defined(ODD)
DATA integer_common/1357/
#else
DATA integer_common/2468/
#endif
END BLOCK DATA hello_blockdata
