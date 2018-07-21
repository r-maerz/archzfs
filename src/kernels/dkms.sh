# For build.sh
mode_name="dkms"
mode_desc="Select and use the dkms packages"

# version
pkgrel="1"

# Version for GIT packages
pkgrel_git="${pkgrel}"
zfs_git_commit=""
spl_git_commit=""
zfs_git_url="https://github.com/zfsonlinux/zfs.git"
spl_git_url="https://github.com/zfsonlinux/spl.git"

header="\
# Maintainer: Jan Houben <jan@nexttrex.de>
# Contributor: Jesus Alvarez <jeezusjr at gmail dot com>
#
# This PKGBUILD was generated by the archzfs build scripts located at
#
# http://github.com/archzfs/archzfs
#"

update_dkms_pkgbuilds() {
    pkg_list=("spl-dkms" "zfs-dkms")
    archzfs_package_group="archzfs-dkms"
    spl_pkgver=${zol_version}
    zfs_pkgver=${zol_version}
    spl_mod_ver=${zol_version}
    zfs_mod_ver=${zol_version}
    spl_pkgrel=${pkgrel}
    zfs_pkgrel=${pkgrel}
    spl_conflicts="'spl-dkms-git'"
    zfs_conflicts="'zfs-dkms-git'"
    spl_pkgname="spl-dkms"
    zfs_pkgname="zfs-dkms"
    spl_utils_pkgname="spl-utils-common=${zol_version}"
    zfs_utils_pkgname="zfs-utils-common=${zol_version}"
    # Paths are relative to build.sh
    spl_dkms_pkgbuild_path="packages/${kernel_name}/${spl_pkgname}"
    zfs_dkms_pkgbuild_path="packages/${kernel_name}/${zfs_pkgname}"
    spl_src_target="https://github.com/zfsonlinux/zfs/releases/download/zfs-${zol_version}/spl-${zol_version}.tar.gz"
    zfs_src_target="https://github.com/zfsonlinux/zfs/releases/download/zfs-${zol_version}/zfs-${zol_version}.tar.gz"
    spl_workdir="\${srcdir}/spl-${zol_version}"
    zfs_workdir="\${srcdir}/zfs-${zol_version}"
}

update_dkms_git_pkgbuilds() {
    pkg_list=("zfs-dkms-git")
    archzfs_package_group="archzfs-dkms-git"
    zfs_pkgver="" # Set later by call to git_calc_pkgver
    zfs_pkgrel=${pkgrel_git}
    zfs_conflicts="'zfs-dkms' 'spl-dkms-git'"
    spl_pkgname=""
    zfs_pkgname="zfs-dkms-git"
    zfs_dkms_pkgbuild_path="packages/${kernel_name}/${zfs_pkgname}"
    zfs_src_target="git+${zfs_git_url}"
    zfs_src_hash="SKIP"
    zfs_makedepends="\"git\""
    zfs_replaces='replaces=("spl-dkms-git")'
    zfs_workdir="\${srcdir}/zfs"

    if have_command "update"; then
        git_check_repo
        git_calc_pkgver
    fi
    zfs_utils_pkgname="zfs-utils-common-git=${zfs_git_ver}"
    zfs_mod_ver="git"
    zfs_src_target="git+${zfs_git_url}#commit=${latest_zfs_git_commit}"
}
