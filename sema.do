
# sema executable

redo-ifchange config.base config

. ./config.base
. ./config

B=build

link $B/main.luac.o $B/supervise.luac.o $B/control.luac.o \
$B/poll.luac.o \
$B/signal.o $B/poll.o $B/init.o \
$B/main.o
