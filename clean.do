
rm -f sema

test -e liblua/clean.do && redo liblua/clean
test -e build/clean.do && redo build/clean

