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
    if [[ ! -e ignore ]] \
        && test -z $(find $pkgdest -maxdepth 1 -name "$pkgname-*$ver*" -print -quit); then
        makepkg -si --asdeps --noconfirm
        retcode=$?
    fi
    popd > /dev/null
    [[ $retcode -ne 0 ]] && exit $retcode
done
