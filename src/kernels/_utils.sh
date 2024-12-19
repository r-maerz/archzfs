archzfs_package_group="archzfs-linux"
zfs_pkgver=${openzfs_version}
zfs_utils_pkgname="zfs-utils"
zfs_utils_pkgbuild_path="packages/_utils/${zfs_utils_pkgname}"
zfs_src_target="https://github.com/openzfs/zfs/releases/download/zfs-${zfs_pkgver}/zfs-${zfs_pkgver}.tar.gz"
zfs_workdir="\${srcdir}/zfs-${zfs_pkgver}"
zfs_utils_replaces='replaces=("zfs-utils-linux" "zfs-utils-linux-lts" "zfs-utils-common")'
