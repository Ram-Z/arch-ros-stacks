#!/bin/bash

get_pkgbuild()
{
    source $1
    echo "pkgname=$pkgname"
    if [[ "$2" == "ros_depends" ]]; then
        echo "depends=( ${ros_depends[@]%%[=<>]*} ${ros_makedepends[@]%%[=<>]*} )"
    elif [[ "$2" == "depends" ]]; then
        echo "depends=( ${depends[@]%%[=<>]*} )"
    else
        echo 'get_pkgbuild() must have either "rosdepends" or "depends" as second argument' >&2
    fi
}

get_version()
{
    source $1
    printf "%s-%s" "$pkgver" "$pkgrel"
}

get_makepkg_conf()
{
    source /etc/makepkg.conf
    echo "pkgdest=${PKGDEST-.}"
    echo "pkgext=${PKGEXT-.pkg.tar.xz}"
}

msg()
{
    local mesg=$1; shift
    local ALL_OFF="$(tput sgr0)"
    local BOLD="$(tput bold)"
    local GREEN="${BOLD}$(tput setaf 2)"
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

get_all()
{
    echo $(find "$1" -name PKGBUILD)
}

get_from_list()
{
    if [[ $# -gt 0 ]]; then
        local pkgs=( $@ )
        dir=${pkgs[0]#ros-}; dir=${dir%%-*}
        local pkgnames=${pkgs[@]#ros-$dir-}
        pkgnames=${pkgnames//-/_}
        for pkg in ${pkgnames[@]}; do
            echo $dir/$pkg/PKGBUILD
        done
    fi
}

get_rosdepends()
{
    for pkgbuild in ${@}; do
        source <(get_pkgbuild $pkgbuild "rosdepends")
        for depend in ${depends[@]}; do
            printf "%s %s\n" "$depend" "$pkgname"
        done
    done
}

get_depends()
{
    for pkgbuild in ${@}; do
        source <(get_pkgbuild $pkgbuild "depends")
        for depend in ${depends[@]}; do
            printf "%s %s\n" "${depend}" "$pkgname"
        done
    done
}

usage()
{
    echo "usage: $(basename "$0") [option] rosdistro"
    echo
    echo "    --force - force rebuilding all packages"
    exit
}

# Argument parsing
packageargs=()
pkgargs=()
while [[ $1 ]]; do
    case "$1" in
        '--force'|'-f') force='1' ;;
        # '--ignore') ignorearg="$2" ; PACOPTS+=("--ignore" "$2") ; shift ;;
        # '--') shift ; packageargs+=("$@") ; break ;;
        -*) echo "$0: Option \`$1' is not valid." ; exit 5 ;;
        groovy*) dir="groovy" ;;
        hydro*)  dir="hydro"  ;;
        indigo*) dir="indigo" ;;
        *) pkgargs+=($1) ;;
    esac
    shift
done

if [[ $dir ]]; then
    pkgbuilds=( $(get_all $dir) )
elif [[ ${#pkgargs[@]} -gt 0 ]]; then
    pkgbuilds=( $(get_from_list ${pkgargs[@]}) )
    dir=${pkgbuilds[0]%%/*}
else
    usage
fi

makepkgopts+=("--asdeps" "--noconfirm")
# [[ $force ]] && makepkgopts+=("--force") || makepkgopts+=("--needed")
[[ $force ]] || makepkgopts+=("--needed")

dependencies=( $(find "./dependencies" -name PKGBUILD) )
sorted_deps=( $(tsort <(get_depends ${dependencies[@]}) ) )

for dependency in ${sorted_deps[@]}; do
    if pacman -Ssq "^$dependency$" > /dev/null; then
        continue
    fi
    if ! pushd dependencies/"${dependency}" > /dev/null 2>&1 ; then
        if [[ "$dependency" =~ "python3" ]]; then
            dependency=${dependency/3/}
        fi
        if ! pushd dependencies/"${dependency}" > /dev/null 2>&1 ; then
            echo "Could not enter dir 'dependencies/${dependency}'" >&2
            continue
        fi
    fi
    # makepkg -si "${makepkgopts[@]}"
    retcode=$?
    popd > /dev/null
    [[ $retcode -ne 0 ]] && exit $retcode
done

exit


sorted=( $(tsort <(get_rosdepends ${pkgbuilds[@]}) ) )
source <(get_makepkg_conf)
for pkgname in ${sorted[@]}; do
    pkgdir=${pkgname#ros-$dir-}
    pkgdir=${pkgdir//-/_}
    pushd "$dir"/$pkgdir > /dev/null
    ver=$(get_version ./PKGBUILD)
    retcode=0
    if [[ ! -e ignore ]]; then
        pkgs=( $(ls --reverse *$pkgext 2> /dev/null) )
        makepkg -si "${makepkgopts[@]}"
        retcode=$?
        # remove old pkgs
        [[ -n "${pkgs[@]:1}" ]] && rm ${pkgs[@]:1}
    fi
    popd > /dev/null
    [[ $retcode -ne 0 ]] && exit $retcode
done
