#!/bin/bash

get_pkgbuild()
{
    source $1
    echo "pkgname=$pkgname"
    echo "depends=( ${ros_depends[@]} ${ros_makedepends[@]} )"
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

tmp=$(mktemp)

get_all()
{
    echo $(find "$dir" -name PKGBUILD)
}

get_depends()
{
    for pkgbuild in ${@}; do
        source <(get_pkgbuild $pkgbuild)
        for depend in ${depends[@]}; do
            printf "%s %s\n" "$depend" "$pkgname" >> $tmp
        done
    done
}

get_from_list()
{
    if [[ $# -gt 0 ]]; then
        local pkgs=( $@ )
        dir=${pkgs[0]#ros-}; dir=${dir%%-*}
        local pkgnames=${pkgs[@]#ros-$dir-}
        pkgnames=${pkgnames[@]//-/_}
        for pkg in ${pkgnames[@]}; do
            echo $dir/$pkg/PKGBUILD
        done
    fi
}

case $1 in
    "")     dir=hydro; pkgbuilds=( $(get_all) ) ;;
    groovy) dir=$1;    pkgbuilds=( $(get_all) ) ;;
    hydro)  dir=$1;    pkgbuilds=( $(get_all) ) ;;
    indigo) dir=$1;    pkgbuilds=( $(get_all) ) ;;
    *)      pkgbuilds=( $(get_from_list $@) ) ;;
esac

get_depends ${pkgbuilds[@]}

sorted=( $(tsort $tmp) )

source <(get_makepkg_conf)
for pkgname in ${sorted[@]}; do
    pkgdir=${pkgname#ros-hydro-}
    pkgdir=${pkgdir//-/_}
    pushd "$dir"/$pkgdir > /dev/null
    ver=$(get_version ./PKGBUILD)
    retcode=0
    if [[ ! -e ignore ]]; then
        pkgs=( $(ls --reverse *$pkgext 2> /dev/null) )
        makepkg -si --asdeps --noconfirm --needed
        retcode=$?
        # remove old pkgs
        [[ -n "${pkgs[@]:1}" ]] && rm ${pkgs[@]:1}
    fi
    popd > /dev/null
    [[ $retcode -ne 0 ]] && exit $retcode
done
