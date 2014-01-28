
# sema executable

. ./config.base

B=build

link $B/main.luac.o $B/supervise.luac.o $B/control.luac.o \
$B/event.luac.o $B/aux.luac.o $B/socket.luac.o $B/poll.luac.o $B/api.luac.o $B/script.luac.o $B/queue.luac.o \
$B/socket.o $B/signal.o $B/children.o $B/poll.o $B/aux.o \
$B/main.o

