
LUA=../liblua/lua

src=$2.luac

redo-ifchange $LUA $src

$LUA ../src/bin2c.lua res_$2_luac < $src > $3

