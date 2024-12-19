kernel_version=$(curl -sL "https://www.archlinux.org/packages/extra/x86_64/linux-hardened/" | \grep -Po -m 1 "(?<=<h2>linux-hardened )[\d\w\.-]+(?=</h2>)")
kernel_version_full=$([[ ${kernel_version} =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(.*)$ ]] && echo ${kernel_version} || ([[ ${kernel_version} =~ ^([0-9]+)\.([0-9]+)([^0-9].*)?$ ]] &&  echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.0${BASH_REMATCH[3]}" || echo ${kernel_version}))
kernel_version_pkgver=$(echo ${kernel_version} | sed s/-/./g)
kernel_version_major=${kernel_version%-*}
kernel_mod_path=${kernel_version/.hardened/-hardened}-hardened
linux_depends="\"linux-hardened=${kernel_version}\""
linux_headers_depends="\"linux-hardened-headers=${kernel_version}\""
zfs_pkgname="zfs-linux-hardened"
archzfs_package_group="archzfs-linux-hardened"
zfs_pkgver=${openzfs_version}
zfs_conflicts="'zfs-linux-hardened-git' 'spl-linux-hardened'"
zfs_replaces='replaces=("spl-linux-hardened")'
zfs_utils_pkgname="zfs-utils=${zfs_pkgver}"
zfs_pkgbuild_path="packages/linux-hardened/${zfs_pkgname}"
zfs_workdir="\${srcdir}/zfs-${zfs_pkgver}"
zfs_src_target="https://github.com/openzfs/zfs/releases/download/zfs-${zfs_pkgver}/zfs-${zfs_pkgver}.tar.gz"
