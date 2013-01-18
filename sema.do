
# sema executable

redo-ifchange config.base config

. ./config.base
. ./config

B=build

link $B/main.luac.o $B/supervise.luac.o $B/control.luac.o \
$B/socket.luac.o $B/poll.luac.o $B/script.luac.o $B/queue.luac.o \
$B/socket.o $B/signal.o $B/children.o $B/poll.o $B/init.o \
$B/main.o
