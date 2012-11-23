
LUAC=../liblua/luac

src=../src/$2.lua

redo-ifchange $LUAC $src

$LUAC -o $3 $src

