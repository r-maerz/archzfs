# For build.sh
mode_name="lts"
package_base="linux-lts"
mode_desc="Select and use the packages for the linux-lts kernel"

# pkgrel for LTS packages
pkgrel="1"

# pkgrel for GIT packages
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
#
# ! WARNING !
#
# The archzfs packages are kernel modules, so these PKGBUILDS will only work with the kernel package they target. In this
# case, the archzfs-linux-lts packages will only work with the default linux-lts package! To have a single PKGBUILD target
# many kernels would make for a cluttered PKGBUILD!
#
# If you have a custom kernel, you will need to change things in the PKGBUILDS. If you would like to have AUR or archzfs repo
# packages for your favorite kernel package built using the archzfs build tools, submit a request in the Issue tracker on the
# archzfs github page.
#"

update_linux_lts_pkgbuilds() {
    get_linux_lts_kernel_version
    kernel_version=${latest_kernel_version}

    pkg_list=("spl-linux-lts" "zfs-linux-lts")
    kernel_version_full=$(kernel_version_full ${kernel_version})
    kernel_version_full_pkgver=$(kernel_version_full_no_hyphen ${kernel_version})
    kernel_version_major=${kernel_version%-*}
    kernel_mod_path="${kernel_version_full}-lts"
    archzfs_package_group="archzfs-linux-lts"
    spl_pkgver=${zol_version}.${kernel_version_full_pkgver}
    zfs_pkgver=${zol_version}.${kernel_version_full_pkgver}
    spl_pkgrel=${pkgrel}
    zfs_pkgrel=${pkgrel}
    spl_conflicts="'spl-linux-lts-git'"
    zfs_conflicts="'zfs-linux-lts-git'"
    spl_pkgname="spl-linux-lts"
    spl_utils_pkgname="spl-utils-common=${zol_version}"
    zfs_pkgname="zfs-linux-lts"
    zfs_utils_pkgname="zfs-utils-common=${zol_version}"
    # Paths are relative to build.sh
    spl_pkgbuild_path="packages/${kernel_name}/${spl_pkgname}"
    zfs_pkgbuild_path="packages/${kernel_name}/${zfs_pkgname}"
    spl_src_target="https://github.com/zfsonlinux/zfs/releases/download/zfs-${zol_version}/spl-${zol_version}.tar.gz"
    zfs_src_target="https://github.com/zfsonlinux/zfs/releases/download/zfs-${zol_version}/zfs-${zol_version}.tar.gz"
    spl_workdir="\${srcdir}/spl-${zol_version}"
    zfs_workdir="\${srcdir}/zfs-${zol_version}"
    linux_depends="\"linux-lts=${kernel_version}\""
    linux_headers_depends="\"linux-lts-headers=${kernel_version}\""
    zfs_makedepends="\"${spl_pkgname}-headers\""
}

update_linux_lts_git_pkgbuilds() {
    get_linux_lts_kernel_version
    kernel_version=${latest_kernel_version}

    pkg_list=("zfs-linux-lts-git")
    kernel_version_full=$(kernel_version_full ${kernel_version})
    kernel_version_full_pkgver=$(kernel_version_full_no_hyphen ${kernel_version})
    kernel_version_major=${kernel_version%-*}
    kernel_mod_path="${kernel_version_full}-lts"
    archzfs_package_group="archzfs-linux-lts-git"
    zfs_pkgver="" # Set later by call to git_calc_pkgver
    zfs_pkgrel=${pkgrel_git}
    zfs_conflicts="'zfs-linux-lts' 'spl-linux-lts-git'"
    spl_pkgname=""
    zfs_pkgname="zfs-linux-lts-git"
    zfs_pkgbuild_path="packages/${kernel_name}/${zfs_pkgname}"
    linux_depends="\"linux-lts=${kernel_version}\""
    linux_headers_depends="\"linux-lts-headers=${kernel_version}\""
    zfs_replaces='replaces=("spl-linux-lts-git")'
    zfs_src_hash="SKIP"
    zfs_makedepends="\"git\""
    zfs_workdir="\${srcdir}/zfs"
    if have_command "update"; then
        git_check_repo
        git_calc_pkgver
    fi
    zfs_utils_pkgname="zfs-utils-common-git=${zfs_git_ver}"
    zfs_src_target="git+${zfs_git_url}#commit=${latest_zfs_git_commit}"
}
