#/usr/bin/env bash

get_name()
{
    source $1
    echo $pkgname
}

get_dep()
{
    source $1
    echo ${ros_depends[@]} ${ros_makedepends[@]}
}

get_version()
{
    source $1
    printf "%s-%s" "$pkgver" "$pkgrel"
}

get_pkgdest()
{
    source /etc/makepkg.conf
    PKGDEST=${PKGDEST-.}
    echo "$PKGDEST"
}

msg() {
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
    pkgname=$(get_name $pkgbuild)
    depends=$(get_dep $pkgbuild)
    for depend in ${depends[@]}; do
        printf "%s %s\n" "$depend" "$pkgname" >> $tmp
    done
done

sorted=( $(tsort $tmp) )

for pkgname in ${sorted[@]}; do
    pkgdir=${pkgname#ros-hydro-}
    pkgdir=${pkgdir//-/_}
    pushd "$dir"/$pkgdir > /dev/null
    ver=$(get_version ./PKGBUILD)
    pkgdest=$(get_pkgdest)
    retcode=0
    if [[ ! -e ignore ]]; then
        if [[ "$pkgname $ver" == "$(pacman -Q $pkgname 2>/dev/null)" ]]; then
            msg "$pkgname-$ver uptodate!"
        elif [[ -z $(find $pkgdest -maxdepth 1 -name "$pkgname-*$ver*" -print -quit) ]]; then
            msg "Building $pkgname"
            makepkg -si --asdeps --noconfirm
        elif [[ -z $(pacman -Qq $pkgname 2> /dev/null) ]]; then
            msg "Installing $pkgname"
            sudo pacman -U --noconfirm --asdeps *.pkg.tar.xz
        fi
        retcode=$?
    fi
    popd > /dev/null
    [[ $retcode -ne 0 ]] && exit $retcode
done
