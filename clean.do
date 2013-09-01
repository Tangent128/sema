
. ./config.base

rm -f sema

test -e liblua/clean.do && redo liblua/clean
dummy=$(vfind build/clean.do) && redo build/clean

