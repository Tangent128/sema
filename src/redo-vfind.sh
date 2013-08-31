
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

	while true ; do
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
	export REDO_VPATH_TARGET="$(readlink -m "$1")"
	shift
	
	target="$1"
	echo "looking to make $target ($2) in $REDO_VPATH_TARGET" >&2
	
	# make needed folders
	targetDir="$REDO_VPATH_TARGET/${target%/*}"
	echo $targetDir >&2
	mkdir -p "$targetDir"
	
	# move into target folder
	cd "$targetDir"
	target="${target##*/}"
	
	#search
	dofile=$target.do
	base=$target
	ext=
	[ -e "$dofile" ] || _find_dofile "$target"
	
	if [ ! -e "$dofile" ]; then
		# no file found
		echo "no .do file found for $target" >&2
		return 1
	fi
	
	if [ "$dofile" -ef "$0" ]; then
		# we just found the dofile that called us, don't loop
		echo "no .do file found for $target" >&2
		return 1
	fi
	
	echo "found dofile $dofile t=$target b=$base e=$ext" >&2
	
	_run_dofile "$target" "$base" "$3"
}

# adapted from minimal-do:

_find_dofile_pwd() {
	dofile=default.$1.do
	while :; do
		dofile=default.${dofile#default.*.}
		echo "$(vfind "$dofile")" $dofile >&2
		if vdofile="$(vfind "$dofile")" ; then
			dofile="${vdofile}"
			break
		fi
		[ "$dofile" = default.do ] && break
	done
	ext=${dofile##*/}
	ext=${ext#default}
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

_run_dofile() {
	set -e
	read line1 <"$dofile" || true
	cmd=${line1#"#!/"}
	if [ "$cmd" != "$line1" ]; then
		/$cmd "$dofile" "$@"
	else
		:; . "$dofile"
	fi
}


