openzfs_version="2.2.6"
openzfs_git_repo="https://github.com/openzfs/zfs.git"
pkgrel=1
kernel_list=("all")
pkg_list=("std" "git" "rc")

header="\
# Maintainer: Robert Maerz
# Contributor: Jan Houben <jan@nexttrex.de>
# Contributor: Jesus Alvarez <jeezusjr at gmail dot com>
#"

linux_rc_configure_flags="--enable-linux-experimental"
