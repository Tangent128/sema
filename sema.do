
# sema executable

redo-ifchange config.base config

. ./config.base
. ./config

B=build

link $B/main.luac.o $B/main.o
