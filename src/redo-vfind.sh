
# shell functions offering vpath-ish behavior for redo, so as to
# facilitate out-of-tree builds. Source directory/ies is/are
# specified in the colon-deliminated $REDO_VPATH environment variable,
# which should be set only by a catchall default.do file in the build root.
# the absolute path of the build root is turn be indicated by
# the $REDO_VPATH_TARGET environment variable, set by the call to vpath
# in the catchall.

# locate a file among the source and target trees, return its actual path
vfind() {
	
	# parse args
	vpath_flag_ifchange=no
	vpath_flag_run=no

	vpath_args=parsing
	while [ $vpath_args = "parsing" ] ; do
		case "$1" in
			"--ifchange")
				vpath_flag_ifchange=yes
				shift
				;;
			"--run")
				vpath_flag_run=yes
				shift
				;;
			*)
				break
				;;
		esac
	done
	
	# see where we are relative to the root
	vpath_dir="${PWD#$REDO_VPATH_TARGET}"
	
	
	# see if file actually exists already
	if [ -e "$1" ] ; then
		_vfind_result "$1"
		return
	fi
	
	# search path
	IFS=:
	for path in $REDO_VPATH ; do
		if [ -e "$path/$vpath_dir/$1" ] ; then
			_vfind_result "$path/$vpath_dir/$1"
			return
		fi
	done
	unset IFS
	
	# not found
	if test $vpath_flag_ifchange = yes ; then
		redo-ifchange "$1" && echo "$1"
	else
		exit 1
	fi
	
}

# run a command, whether in the targets or sources
vrun() {
	vpath_cmd="$( vfind "$1" )" || return
	shift
	"$( readlink -e "$vpath_cmd" )" "$@"
}

_vfind_result() { # $1 = path, rest = command args
	if test $vpath_flag_ifchange = yes ; then
		redo-ifchange "$1" || return
	fi
	
	echo "$1"
}

# proxy a dofile search to the source trees, run it where it should
vpath() { # $1 is target root directory (best if not .), followed by standard redo args
	target="$1"
	echo "looking to make $target ($2)" >&2
	
	dofile=$target.do
	base=$target
	ext=
	[ -e "$dofile" ] || _find_dofile "$target"
	if [ ! -e "$dofile" ]; then
		echo "no .do file found for $target" >&2
		return 1
	fi
	echo "found dofile $dofile" >&2
}

# copied from minimal-do:

_find_dofile_pwd() {
	dofile=default.$1.do
	while :; do
		dofile=default.${dofile#default.*.}
		[ -e "$dofile" -o "$dofile" = default.do ] && break
	done
	ext=${dofile#default}
	ext=${ext%.do}
	base=${1%$ext}
}


_find_dofile() {
	local prefix=
	while :; do
		_find_dofile_pwd "$1"
		[ -e "$dofile" ] && break
		[ "$PWD" = "/" ] && break
		target=${PWD##*/}/$target
		tmp=${PWD##*/}/$tmp
		prefix=${PWD##*/}/$prefix
		cd ..
	done
	base=$prefix$base
}

#nix
_run_dofile() {
	export DO_DEPTH="$DO_DEPTH  "
	export REDO_TARGET=$PWD/$target
	local line1
	set -e
	read line1 <"$PWD/$dofile" || true
	cmd=${line1#"#!/"}
	if [ "$cmd" != "$line1" ]; then
		/$cmd "$PWD/$dofile" "$@" >"$tmp.tmp2"
	else
		:; . "$PWD/$dofile" >"$tmp.tmp2"
	fi
}


