kernel_version=$(curl -sL "https://www.archlinux.org/packages/extra/x86_64/linux-zen/" | \grep -Po -m 1 "(?<=<h2>linux-zen )[\d\w\.-]+(?=</h2>)")
kernel_version_full=$([[ ${kernel_version} =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(.*)$ ]] && echo ${kernel_version} || ([[ ${kernel_version} =~ ^([0-9]+)\.([0-9]+)([^0-9].*)?$ ]] &&  echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.0${BASH_REMATCH[3]}" || echo ${kernel_version}))
kernel_version_pkgver=$(echo ${kernel_version} | sed s/-/./g)
kernel_version_major=${kernel_version%-*}
kernel_mod_path="${kernel_version_full/.zen/-zen}-zen"
linux_depends="\"linux-zen=${kernel_version}\""
linux_headers_depends="\"linux-zen-headers=${kernel_version}\""
zfs_pkgname="zfs-linux-zen"
archzfs_package_group="archzfs-linux-zen"
zfs_pkgver=${openzfs_version}
zfs_conflicts="'zfs-linux-zen-git' 'spl-linux-zen'"
zfs_replaces='replaces=("spl-linux-zen")'
zfs_utils_pkgname="zfs-utils=${zfs_pkgver}"
zfs_pkgbuild_path="packages/linux-zen/${zfs_pkgname}"
zfs_workdir="\${srcdir}/zfs-${zfs_pkgver}"
zfs_src_target="https://github.com/openzfs/zfs/releases/download/zfs-${zfs_pkgver}/zfs-${zfs_pkgver}.tar.gz"
