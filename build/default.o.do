
redo-ifchange ../config.base ../config

. ../config.base
. ../config

# $CC $LUAINC ../src/$2.c -o $3

compile ../src/$2.c

