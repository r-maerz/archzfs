#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

main() {
unset ZFS_VERSION
unset ZFS_RC_VERSION
unset ZFS_GIT_VERSION
unset RELEASE
unset KERNELS
unset PKG_LIST

args=$(getopt -a -o z:c:g:r:k: --long zfs-version:,zfs-rc-version:,zfs-git-version:,release:,kernels: -- "$@")
if [[ $? -gt 0 ]]; then
  usage
fi

eval set -- ${args}
while :
do
  case $1 in
    -z | --zfs-version)   ZFS_VERSION=$2    ; shift 2  ;;
    -c | --zfs-rc-version)   ZFS_RC_VERSION=$2     ; shift 2  ;;
    -g | --zfs-git-version)   ZFS_GIT_VERSION=$2     ; shift 2 ;;
    -r | --release)    RELEASE=$2      ; shift 2  ;;
    -k | --kernels)   KERNELS=$2   ; shift 2 ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    *) >&2 echo Unsupported option: $1
       usage ;;
  esac
done

PKG_LIST=()
ZFS_VERSIONS=""
SCRIPTDIR="$(pwd)"
source ${SCRIPTDIR}/conf.sh

if ! [ -z ${ZFS_VERSION+x} ]; then
  openzfs_version=$ZFS_VERSION;
  zfs_std_src_hash=$(curl -sL "https://github.com/openzfs/zfs/releases/download/zfs-${openzfs_version}/zfs-${openzfs_version}.sha256.asc" | sed -n "/zfs-${openzfs_version}/p" | cut -d " " -f 1)
  PKG_LIST+=("std")
  ZFS_VERSIONS+="\n  zfs_version: ${openzfs_version}"
fi
if ! [ -z ${ZFS_RC_VERSION+x} ]; then
  openzfs_rc_version=$ZFS_RC_VERSION;
  zfs_rc_src_hash=$(curl -sL "https://github.com/openzfs/zfs/releases/download/zfs-${openzfs_rc_version}/zfs-${openzfs_rc_version}.sha256.asc" | sed -n "/zfs-${openzfs_rc_version}/p" | cut -d " " -f 1)
  if [ -z ${zfs_rc_src_hash} ]; then zfs_rc_src_hash="SKIP"; fi
  PKG_LIST+=("rc")
  ZFS_VERSIONS+="\n  zfs_rc_version: ${openzfs_rc_version}"
fi
if ! [ -z ${ZFS_GIT_VERSION+x} ]; then
  calculate_git_variables
  PKG_LIST+=("git")
  ZFS_VERSIONS+="\n  zfs_git_version: ${openzfs_git_version}"
fi
if ! [ -z ${RELEASE+x} ]; then PKGREL=$RELEASE; else PKGREL=$pkgrel; fi
if ! [ -z ${KERNELS+x} ]; then KERNEL_LIST=($KERNELS); else KERNEL_LIST=("${kernel_list[@]}"); fi
if [[ " ${KERNEL_LIST[*]} " =~ "all" ]] then KERNEL_LIST=("_utils" "dkms" "linux" "linux-lts" "linux-hardened" "linux-zen"); fi
echo -e "\n${BLUE}==>${WHITE} Working with \n{${ZFS_VERSIONS}\n  kernels: $(echo ${KERNEL_LIST[@]} | tr ' ' ',')\n  release: ${PKGREL}\n}${NOCOLOR}\n"

create_pkgbuilds

echo -e "${GREEN}==>${WHITE} Done!${NOCOLOR}"

}

usage(){
>&2 cat << EOF
Usage: $0
   [ -z | --zfs-version <string> ]
   [ -c | --zfs-rc-version <string> ]
   [ -g | --zfs-git-version <string> ]
   [ -r | --release <integer> ]
   [ -k | --kernels <string> (space delimited) ]
EOF
exit 1
}

reset_variable_values(){  
kernel_version_pkgver=""
kernel_version_full=""
kernel_version=""
zfs_pkgver=""
zfs_pkgrel=""
zfs_makedepends=""
zfs_conflicts=""
zfs_pkgname=""
zfs_utils_pkgname=""
zfs_pkgbuild_path=""
zfs_dkms_pkgbuild_path=""
zfs_src_target=""
zfs_workdir=""
linux_depends=""
linux_headers_depends=""
zfs_replaces=""
zfs_set_commit=""
zfs_replaces=""
zfs_utils_replaces=""
zfs_mod_ver=""
}

calculate_git_variables(){
echo -e "${BLUE}==>${WHITE} Ensuring git is installed ...${NOCOLOR}\n"
pacman-key --init && pacman -Syy
if [[ ! $(pacman -Qi git | grep "Version") ]]; then pacman -S --noconfirm --needed git; fi

echo -e "${BLUE}==>${WHITE} git packages have been requested. Calculating variables ...${NOCOLOR}\n"
if [ -d "temp/openzfs" ]; then rm -Rf "temp/openzfs"; fi
mkdir -p "temp/openzfs"
  
git clone ${openzfs_git_repo} "temp/openzfs"
cd "temp/openzfs"

git -c advice.detachedHead=false checkout ${ZFS_GIT_VERSION}
openzfs_git_version=$(printf "%s.r%s.g%s" "$(git log -n 1 --pretty=format:"%cd" --date=short | sed "s/-/./g")" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)")
zfs_git_src_hash=$(git -c core.abbrev=no -C . archive --format tar ${ZFS_GIT_VERSION} | sha256sum | cut -d " " -f 1)
zfs_git_commit=$(git rev-parse HEAD)

cd ${SCRIPTDIR}
rm -rf "temp/openzfs"
}

create_pkgbuilds(){
for KERNEL_NAME in "${KERNEL_LIST[@]}"; do
  for PKG in "${PKG_LIST[@]}"; do
    if [[ $PKG == "std" ]]; then PKGDISPLAY=""; else PKGDISPLAY="-${PKG}"; fi
    echo -e "${BLUE}==>${WHITE} Creating PKGBUILD for: ${KERNEL_NAME}${PKGDISPLAY}${NOCOLOR}\n"

    reset_variable_values
    source ${SCRIPTDIR}/src/kernels/${KERNEL_NAME}.sh

    case $PKG in
      "std")
        zfs_pkgver=$openzfs_version
	zfs_src_hash=$zfs_std_src_hash
	zfs_replaces="replaces=(\"spl-${KERNEL_NAME}\")"
	zfs_conflicts="'zfs-${KERNEL_NAME}-git' 'zfs-${KERNEL_NAME}-rc' 'spl-${KERNEL_NAME}'"
        ;;

      "rc")
        zfs_pkgver=${openzfs_rc_version/-/_}
	zfs_src_hash=$zfs_rc_src_hash
	zfs_pkgname="${zfs_pkgname}-rc"
	zfs_src_target="https://github.com/openzfs/zfs/releases/download/zfs-${openzfs_rc_version}/zfs-${openzfs_rc_version}.tar.gz"
	zfs_workdir="\${srcdir}/zfs-${openzfs_rc_version}"
	archzfs_package_group="${archzfs_package_group}-rc"
	zfs_utils_replaces='replaces=("zfs-utils-linux" "zfs-utils-linux-lts" "zfs-utils-common")'
	zfs_replaces="replaces=(\"spl-${KERNEL_NAME}-rc\")"
	zfs_conflicts="'zfs-${KERNEL_NAME}' 'zfs-${KERNEL_NAME}-git' 'spl-${KERNEL_NAME}-rc'"
	if [[ $KERNEL_NAME == "_utils" ]]; then
          zfs_utils_pkgname="${zfs_utils_pkgname}-rc"
        else
          zfs_utils_pkgname="zfs-utils-rc=${zfs_pkgver}"
        fi
        ;;

      "git")
        zfs_pkgver=$openzfs_git_version
	zfs_src_hash=$zfs_git_src_hash
	zfs_pkgname="${zfs_pkgname}-git"
	zfs_workdir="\${srcdir}/zfs"
	archzfs_package_group="${archzfs_package_group}-git"
	zfs_utils_replaces='replaces=("spl-utils-common-git" "zfs-utils-common-git")'
	zfs_replaces="replaces=(\"spl-${KERNEL_NAME}-git\")"
	zfs_conflicts="'zfs-${KERNEL_NAME}' 'zfs-${KERNEL_NAME}-rc' 'spl-${KERNEL_NAME}-git'"
	zfs_makedepends="\"git\""
	zfs_set_commit="_commit='$zfs_git_commit'"
        zfs_src_target="git+${openzfs_git_repo}#commit=\${_commit}"
	if [[ $KERNEL_NAME == "_utils" ]]; then
          zfs_utils_pkgname="${zfs_utils_pkgname}-git"
        else
          zfs_utils_pkgname="zfs-utils-git=${zfs_pkgver}"
        fi
        ;;
    esac

    zfs_pkgrel=${PKGREL}
    zfs_mod_ver=${zfs_pkgver}
    zfs_pkgbuild_path="packages/${KERNEL_NAME}/${zfs_pkgname}"
    zfs_utils_pkgbuild_path="packages/_utils/${zfs_utils_pkgname}"
    zfs_dkms_pkgbuild_path="packages/dkms/${zfs_pkgname}"

    if [[ ! -d "${zfs_pkgbuild_path}" ]] && [[ ${KERNEL_NAME} != "_utils" ]]; then
      echo -e "${YELLOW}==> WARN:${WHITE} folder ${zfs_pkgbuild_path} does not exist. Skipping package ...${NOCOLOR}\n"
    else
      if [[ "${KERNEL_NAME}" == "_utils" ]]; then
        # Removing old zfs-utils patches (if any)
        rm -f ${zfs_utils_pkgbuild_path}/*.patch
        # Removing old bash completion file
        rm -f ${zfs_utils_pkgbuild_path}/zfs-utils.bash-completion-r1
        # Copying zfs-utils patches (if any)
        find ${SCRIPTDIR}/src/zfs-utils -name \*.patch -exec cp {} ${zfs_utils_pkgbuild_path} \;
        # Creating zfs-utils.install
        source ${SCRIPTDIR}/src/zfs-utils/zfs-utils.install.sh
        # Copying zfs-utils hooks
        cp ${SCRIPTDIR}/src/zfs-utils/*.hook ${zfs_utils_pkgbuild_path}/
        # Copying zfs-utils hook install files"
        cp ${SCRIPTDIR}/src/zfs-utils/*.install ${zfs_utils_pkgbuild_path}/
        # Calculate current checksum values of .install and .hook files
        zfs_initcpio_hook_hash=$(sha256sum ${zfs_utils_pkgbuild_path}/zfs-utils.initcpio.hook | cut -d " " -f 1)
        zfs_initcpio_install_hash=$(sha256sum ${zfs_utils_pkgbuild_path}/zfs-utils.initcpio.install | cut -d " " -f 1)
        zfs_initcpio_zfsencryptssh_install=$(sha256sum ${zfs_utils_pkgbuild_path}/zfs-utils.initcpio.zfsencryptssh.install | cut -d " " -f 1)
        # Creating zfs-utils PKGBUILD
        source ${SCRIPTDIR}/src/zfs-utils/PKGBUILD.sh
      elif [[ "${KERNEL_NAME}" == "dkms" ]]; then
        # Removing old zfs patches (if any)
        rm -f ${zfs_dkms_pkgbuild_path}/*.patch
        # Copying zfs patches (if any)
        find ${SCRIPTDIR}/src/zfs-dkms -name \*.patch -exec cp {} ${zfs_dkms_pkgbuild_path} \;
        # Creating zfs-dkms PKGBUILD
        source ${SCRIPTDIR}/src/zfs-dkms/PKGBUILD.sh
      else
        # Removing old zfs patches (if any)
        rm -f ${zfs_pkgbuild_path}/*.patch
        # Copying zfs patches (if any)
        find ${SCRIPTDIR}/src/zfs -name \*.patch -exec cp {} ${zfs_pkgbuild_path} \;
        # Creating zfs PKGBUILD
        source ${SCRIPTDIR}/src/zfs/PKGBUILD.sh
        # Creating zfs.install
        source ${SCRIPTDIR}/src/zfs/zfs.install.sh
      fi
    fi
  done
done
}

main "$@"; exit
