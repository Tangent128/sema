
. ../config.base

src=$2.luac

redo-ifchange $LUADEP $src

$LUA $(vfind $ROOT/src/bin2c.lua) res_$2_luac < $src > $3

