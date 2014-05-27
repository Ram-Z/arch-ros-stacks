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
dir=${1-:.}
pkgbuilds=$(find "$dir" -name PKGBUILD)
for pkgbuild in ${pkgbuilds[@]}; do
    source <(get_pkgbuild $pkgbuild)
    for depend in ${depends[@]}; do
        printf "%s %s\n" "$depend" "$pkgname" >> $tmp
    done
done

sorted=( $(tsort $tmp) )

source <(get_makepkg_conf)
for pkgname in ${sorted[@]}; do
    pkgdir=${pkgname#ros-hydro-}
    pkgdir=${pkgdir//-/_}
    pushd "$dir"/$pkgdir > /dev/null
    ver=$(get_version ./PKGBUILD)
    retcode=0
    if [[ ! -e ignore ]]; then
        pkgs=( $(ls --reverse *$pkgext) )
        if [[ "$pkgname $ver" == "$(pacman -Q $pkgname 2>/dev/null)" ]]; then
            msg "$pkgname-$ver uptodate!"
        elif [[ -z $(find $pkgdest -maxdepth 1 -name "$pkgname-*$ver*$pkgext" -print -quit) ]]; then
            msg "Building $pkgname"
            makepkg -si --asdeps --noconfirm
        elif [[ -z $(pacman -Qq $pkgname 2> /dev/null) ]]; then
            msg "Installing $pkgname"
            sudo pacman -U --noconfirm --asdeps ${pkgs[0]}
        fi
        retcode=$?
        # remove old pkgs
        [[ -n "${pkgs[@]:1}" ]] && rm ${pkgs[@]:1}
    fi
    popd > /dev/null
    [[ $retcode -ne 0 ]] && exit $retcode
done