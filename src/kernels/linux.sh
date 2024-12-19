kernel_version=$(curl -sL "https://www.archlinux.org/packages/core/x86_64/linux/" | \grep -Po -m 1 "(?<=<h2>linux )[\d\w\.-]+(?=</h2>)")
kernel_version_full=$([[ ${kernel_version} =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(.*)$ ]] && echo ${kernel_version} || ([[ ${kernel_version} =~ ^([0-9]+)\.([0-9]+)([^0-9].*)?$ ]] &&  echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.0${BASH_REMATCH[3]}" || echo ${kernel_version}))
kernel_version_pkgver=$(echo ${kernel_version} | sed s/-/./g)
kernel_version_major=${kernel_version%-*}
kernel_mod_path=${kernel_version_full/.arch/-arch}
linux_depends="\"linux=${kernel_version}\""
linux_headers_depends="\"linux-headers=${kernel_version}\""
zfs_pkgname="zfs-linux"
archzfs_package_group="archzfs-linux"
zfs_pkgver=${openzfs_version}
zfs_conflicts="'zfs-linux-git' 'zfs-linux-rc' 'spl-linux'"
zfs_replaces='replaces=("spl-linux")'
zfs_utils_pkgname="zfs-utils=${zfs_pkgver}"
zfs_pkgbuild_path="packages/linux/${zfs_pkgname}"
zfs_workdir="\${srcdir}/zfs-${zfs_pkgver}"
zfs_src_target="https://github.com/openzfs/zfs/releases/download/zfs-${zfs_pkgver}/zfs-${zfs_pkgver}.tar.gz"
extra_configure_flags=${linux_configure_flags}
