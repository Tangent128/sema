
# shell functions offering vpath-ish behavior for redo, so as to
# facilitate out-of-tree builds. Source directory/ies is/are
# specified in the colon-deliminated $REDO_VPATH environment variable,
# which should be set only by a catchall default.do file in the build root.
# the absolute path of the build root is turn be indicated by
# the $REDO_VPATH_TARGET environment variable, set by the call to vpath
# in the catchall.

# locate a file among the source and target trees, return its actual path;
# only works properly when called from under the target tree
vfind() {
	
	# if a in-tree build, nothing to look for
	if [ ! "$REDO_VPATH_TARGET" ] ; then
		echo "$1"
		return
	fi

	# see where we are relative to the root
	vpath_dir="${PWD#$REDO_VPATH_TARGET}"

	# results
	vpath_results=
	vpath_success=0

	# loop over args	
	while [ "$1" ] ; do
		_debug "arg $1"
		vpath_results="$vpath_results $(_vfind_file "$1")" || vpath_success=1
		shift
	done
	
	echo $vpath_results
	_debug "$vpath_success $vpath_results"
	return $vpath_success
}

_vfind_file() {
	
	# see if file actually exists already
	# (or should only use for source-tree files?)
	#if [ -e "$1" ] ; then
	#	echo "$1"
	#	return
	#fi
	
	# express source relative to the tree root
	case $1 in
		/*)
			# was an absolute path
			vpath_source=${1#$REDO_VPATH_TARGET}
			;;
		*)
			# was a relative path
			vpath_source="$vpath_dir/$1"
			;;
	esac
	
	_debug "finding $vpath_source"
	
	# search path
	IFS=:
	for path in $REDO_VPATH ; do
		_debug "try $path/$vpath_source"
		if [ -e "$path/$vpath_source" ] ; then
			_debug "found $1"
			echo "$path/$vpath_source"
			return 0
		fi
	done
	unset IFS
	
	# not found
	return 1
	
}

# run a command, whether in the targets or sources
vrun() {
	vpath_cmd="$( vfind "$1" )" || return
	shift
	"$( readlink -e "$vpath_cmd" )" "$@"
}

_vfind_result() { # $1 = path
	echo "$1"
}

# proxy a dofile search to the source trees, run it in the associated build tree folder
vpath() { # $1 is target root directory, followed by standard redo args
_debug "VPATH $*"
	vpath_prefix="$1"
	export REDO_VPATH_TARGET="$(readlink -m "$vpath_prefix")"
	shift
	
	# adjust $1 to get value relative to target root
	target="${1#$vpath_prefix}"
	target="${target#/}"
	
	# get absolute path to temporary target file
	tmpTarget="$(readlink -m "$3")"
	_debug "looking to make $target (as $tmpTarget) in $REDO_VPATH_TARGET"
	
	# make needed folders
	targetDir="$REDO_VPATH_TARGET/$(dirname "$target")"
	_debug "targetDir $targetDir"
	mkdir -p "$targetDir"
	
	# move into target folder
	cd "$targetDir"
	target="${target##*/}"
	
	#search
	dofile=$target.do
	base=$target
	ext=
	dofile="$(vfind "$dofile")" || _find_dofile "$target"
	
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
	
	_debug "found dofile $dofile t=$target b=$base e=$ext"
	
	# add dependency on dofile
	redo-ifchange "$dofile"
	
	# change to native directory
	cd "$(dirname "$dofile")"
	
	# add nonstandard $4 = target file directory, for cd-ing back
	_run_dofile "$target" "$base" "$tmpTarget" "$targetDir"
}

# adapted from minimal-do:

_find_dofile_pwd() {
	dofile=default.$1.do
	while :; do
		dofile=default.${dofile#default.*.}
		if vdofile="$(vfind "$dofile")" ; then
			dofile="$vdofile"
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

_debug() {
	#echo "$1" >&2
	:
}

