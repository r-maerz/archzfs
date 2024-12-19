#!/bin/bash
#
# This script builds the archzfs packages in a clean chroot environment.
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

main() {
  unset KERNELS
  unset PACKAGES
  unset WORK_IN_DIR
  unset BUILD_AS_USER
  unset SETUP_CHROOT

  args=$(getopt -a -o k:p:d:u:c --long kernels:,packages:,work-dir:,build-user:,create-chroot -- "$@")
  if [[ $? -gt 0 ]]; then
    usage
  fi

  eval set -- ${args}
  while :
  do
    case $1 in
      -k | --kernels)   KERNELS=$2   ; shift 2 ;;
      -p | --packages)   PACKAGES=$2   ; shift 2 ;;
      -d | --work-dir)   WORK_IN_DIR=$2   ; shift 2 ;;
      -u | --build-user) BUILD_AS_USER=$2   ; shift 2 ;;
      -c | --create-chroot)    SETUP_CHROOT=1   ; shift 1 ;;
      # -- means the end of the arguments; drop this, and break out of the while loop
      --) shift; break ;;
      *) >&2 echo Unsupported option: $1
         usage ;;
    esac
  done

  RANDINT=${RANDOM:0:4}
  SCRIPTDIR="$(pwd)"
  source "${SCRIPTDIR}/conf.sh"

  if ! [ -z ${KERNELS+x} ]; then KERNEL_LIST=($KERNELS); else KERNEL_LIST=("${kernel_list[@]}"); fi
  if [[ " ${KERNEL_LIST[*]} " =~ "all" ]] then KERNEL_LIST=("_utils" "dkms" "linux" "linux-lts" "linux-hardened" "linux-zen"); fi
  if ! [ -z ${PACKAGES+x} ]; then PKG_LIST=($PACKAGES); else PKG_LIST=("${pkg_list[@]}"); fi
  if [[ " ${PKG_LIST[*]} " =~ "all" ]] then PKG_LIST=("std" "git" "rc"); fi
  if ! [ -z ${WORK_IN_DIR+x} ]; then WORKDIR=$WORK_IN_DIR; else WORKDIR="/archzfs_${RANDINT}"; fi
  if ! [ -z ${BUILD_AS_USER+x} ]; then BUILD_USER=$BUILD_AS_USER; else BUILD_USER="buildbot_${RANDINT}"; fi
  if ! [ -z ${SETUP_CHROOT+x} ]; then CHROOT_SETUP=1; fi
  echo -e "\n${BLUE}==>${WHITE} Working with \n{\n  kernels: $(echo ${KERNEL_LIST[@]} | tr ' ' ',')\n  packages: $(echo ${PKG_LIST[@]} | tr ' ' ',')\n  build_user: ${BUILD_USER}\n  work_dir: ${WORKDIR}\n  create_chroot: $([[ $CHROOT_SETUP -eq 1 ]] && echo 'true' || echo 'false')\n}${NOCOLOR}\n"

  if [[ $(readlink -f "${WORKDIR}") == *"${SCRIPTDIR}"* ]]; then
    echo -e "${RED}==> ERROR:${WHITE} ${WORKDIR} (WORKDIR) is a subdirectory of ${SCRIPTDIR} (SCRIPTDIR).\nREFUSING.${NOCOLOR}"
    exit 155;
  fi

  BINDDIR="${WORKDIR}/source"
  CHROOTDIR="${WORKDIR}/chroot"
  REPODIR="${WORKDIR}/repo"
  STARTTIMEINSEC=$(date +%s);

  add_builduser

  if [[ $CHROOT_SETUP -eq 1 ]]; then
    create_chroot
    create_repo
  else
    create_repo
  fi

  fix_permissions

  for KERNEL_NAME in ${KERNEL_LIST[@]}; do
    build_packages
    build_sources
  done

  remove_builduser
  ENDTIMEINSEC=$(date +%s);
  echo -e "${GREEN}==>${WHITE} Done! Script took $(date -u -d "0 $ENDTIMEINSEC sec - $STARTTIMEINSEC sec" +"%H:%M:%S") to finish.${NOCOLOR}"

}

usage(){                                                                                                                                                                                                         >&2 cat << EOF
Usage: $0
   [ -k | --kernels <string> (space delimited) ]
   [ -p | --packages <string> (space delimited) ]
   [ -d | --work_dir <string> (absolute path) ]
   [ -u | --build-user <string> (username) ]
   [ -c | --create_chroot ]
EOF
exit 1
}

add_builduser(){
  echo -e "${BLUE}==>${WHITE} Ensuring sudo is installed ...${NOCOLOR}\n"
  pacman-key --init && pacman -Syy
  if [[ ! $(pacman -Qi sudo | grep "Version") ]]; then pacman -S --noconfirm --needed sudo; fi
      
  echo -e "${BLUE}==>${WHITE} Creating build user ${BUILD_USER} ...${NOCOLOR}\n"
  if [[ $(getent passwd ${BUILD_USER}) ]]; then
    echo -e "${YELLOW}==> WARN:${WHITE} ${BUILD_USER} exists, skipping creation ...${NOCOLOR}\n"
  else
    useradd -r -s /sbin/false ${BUILD_USER}
  fi

  if [ ! -d "${WORKDIR}" ]; then mkdir -p "${WORKDIR}"; fi
  WORKDIR=$(readlink -e ${WORKDIR})
  OG_WORKDIR_USER="$(stat -c '%U' "${WORKDIR}")"
  chown -R ${BUILD_USER}:${BUILD_USER} ${WORKDIR}

  sudo -u ${BUILD_USER} test -w "${WORKDIR}" || { \
    echo -e "${RED}==> ERROR:${WHITE} ${BUILD_USER} can not access '${WORKDIR}'.\n${NOCOLOR}Removing build user (if it is a buildbot) and aborting."; \
    if [[ ${BUILD_USER} == *"buildbot"* ]]; then userdel ${BUILD_USER}; fi; \
    chown -R ${OG_WORKDIR_USER}:${OG_WORKDIR_USER} $WORKDIR; \
    exit 155; \
  }

  if [[ ! $(logname) == ${BUILD_USER} ]]; then
    echo -e "${BLUE}==>${WHITE} Granting limited sudo rights to ${BUILD_USER} ...${NOCOLOR}\n"
    echo -e "Defaults env_keep += \"BUILDTOOL BUILDTOOLVER\"\n${BUILD_USER} ALL=(ALL) NOPASSWD: /usr/bin/tee,/usr/bin/rm,/usr/bin/pacman,/usr/bin/mkarchroot,/usr/bin/makechrootpkg" | tee /etc/sudoers.d/zzz_${BUILD_USER} > /dev/null
  fi
}

remove_builduser(){
  echo -e "${BLUE}==>${WHITE} Moving repositories to SCRIPTDIR ...${NOCOLOR}\n"
  mv ${REPODIR} ${SCRIPTDIR}/

  echo -e "${BLUE}==>${WHITE} Fixing SCRIPTDIR ownership ...${NOCOLOR}\n"
  cd ${SCRIPTDIR}

  if [[ -f /.dockerenv ]]; then
    echo -e "${YELLOW}==>WARN:${WHITE} Build ran inside Docker; setting owner of SCRIPTDIR to root ...${NOCOLOR}\n"
    chown -R root:root "${SCRIPTDIR}"
  else
    chown -R ${OG_SCRIPTDIR_USER}:${OG_SCRIPTDIR_USER} "${SCRIPTDIR}"
  fi

  echo -e "${BLUE}==>${WHITE} Removing working directory, sudo config and build user (if it is a buildbot) ...${NOCOLOR}\n"
  if [[ ${BUILD_USER} == *"buildbot"* ]]; then
    userdel ${BUILD_USER}
  fi
  rm -f /etc/sudoers.d/zzz_${BUILD_USER}
  sleep 5
  umount -R ${BINDDIR}
  sleep 2
  if [[ ! $(findmnt -M ${BINDDIR}) ]]; then rm -rf ${WORKDIR}; fi
}

fix_permissions(){
  if [ -d "${BINDDIR}" ]; then umount -R ${BINDDIR} ||: ; fi
  echo -e "${BLUE}==>${WHITE} Creating bind mount and fixing permissions ...${NOCOLOR}\n"
  mkdir -p "${BINDDIR}"
  mount --bind ${SCRIPTDIR} ${BINDDIR}

  OG_SCRIPTDIR_USER="$(stat -c '%U' "${SCRIPTDIR}")"
  chown -R ${BUILD_USER}:${BUILD_USER} "${BINDDIR}"
  chown -R ${BUILD_USER}:${BUILD_USER} "${REPODIR}"
}

create_chroot() {
  echo -e "${BLUE}==>${WHITE} Check if Docker fixes are needed ...${NOCOLOR}\n"
  
  if [[ -f /.dockerenv ]]; then
    sed -i 's/^NoExtract/#&/g' /etc/pacman.conf
    systemd-machine-id-setup
  fi
  
  if [ -d "${CHROOTDIR}" ]; then rm -Rf "${CHROOTDIR}"; fi
  mkdir -p "${CHROOTDIR}"

  echo -e "${BLUE}==>${WHITE} Ensuring devtools are installed ...${NOCOLOR}\n"
  if [[ ! $(pacman -Qi devtools | grep "Version") ]]; then pacman -S --noconfirm --needed devtools; fi
  echo -e "${BLUE}==>${WHITE} Creating minimal chroot environment ...${NOCOLOR}"
  mkarchroot ${CHROOTDIR}/root base-devel
}

create_repo(){
  echo -e "${BLUE}==>${WHITE} Removing previous versions of repositories ...${NOCOLOR}\n"
  if [ -d "${REPODIR}" ]; then rm -Rf "${REPODIR}"; fi
  if [ -d "${SCRIPTDIR}/repo" ]; then rm -Rf "${SCRIPTDIR}/repo"; fi
  
  echo -e "${BLUE}==>${WHITE} Updating pacman.conf and makepkg.conf inside chroot ...${NOCOLOR}\n"
  for PKG in "${PKG_LIST[@]}"; do
    mkdir -p "${REPODIR}/${PKG}"
    echo -e "\n[archzfs_${PKG}]\nSigLevel = Optional TrustAll\nServer = file://${REPODIR}/${PKG}" | tee -a $CHROOTDIR/root/etc/pacman.conf > /dev/null
    repo-add "${REPODIR}/${PKG}/archzfs_${PKG}.db.tar.zst"
  done

  echo -e "\nPACKAGER=\"ArchZFS Project <https://github.com/archzfs>\"" | tee -a $CHROOTDIR/root/etc/makepkg.conf > /dev/null
}

cleanup() {
  # $1: the package name
  echo -e "${BLUE}==>${WHITE} Cleaning up work files ...${NOCOLOR}\n"
  find ${BINDDIR}/packages/${KERNEL_NAME}/$1 -iname "*.log" -o -iname "*.pkg.tar.zst*" -o -iname "*.src.tar.gz" | xargs rm -rf
  rm -rf */src
  rm -rf */*.tar.gz
  ls -alh
}

build_packages() {
  unset PKG_KERNEL_NAME
  unset LOCAL_PKG_FILES
  PKG_KERNEL_NAME=${KERNEL_NAME/_/-}

  for PKG in "${PKG_LIST[@]}"; do
    if [[ $PKG = "std" ]]; then
      PKG_FULLNAME="zfs-${PKG_KERNEL_NAME}"
    else
      PKG_FULLNAME="zfs-${PKG_KERNEL_NAME}-${PKG}"
    fi

    PKG_FULLNAME=${PKG_FULLNAME/--/-}

    if ! [ -d "${BINDDIR}/packages/${KERNEL_NAME}/${PKG_FULLNAME}" ]; then
      echo -e "${YELLOW}==> WARN:${WHITE} Requested build of ${KERNEL_NAME}/${PKG_FULLNAME} but directory does not exist. Skipping ...${NOCOLOR}\n"
    else
      cd "${BINDDIR}/packages/${KERNEL_NAME}/${PKG_FULLNAME}"
      if [[ -f ./PKGBUILD ]]; then
        echo -e "${BLUE}==>${WHITE} Building package ${KERNEL_NAME}/${PKG_FULLNAME} ...${NOCOLOR}\n"
        # Cleanup all previously built packages for the current package
        cleanup ${PKG_FULLNAME}
        makechrootpkg -c -u -U ${BUILD_USER} -r ${CHROOTDIR} -d ${REPODIR} || true

        LOCAL_PKG_FILES=($(find "${BINDDIR}/packages/${KERNEL_NAME}/${PKG_FULLNAME}/" -maxdepth 1 -name "*.pkg.tar.zst"))
        if [ ${#LOCAL_PKG_FILES[@]} -gt 0 ]; then
          for LOCAL_PKG in "${LOCAL_PKG_FILES[@]}"; do
            cp "${LOCAL_PKG}" "${REPODIR}/${PKG}/"
          done
          repo-add "${REPODIR}/${PKG}/archzfs_${PKG}.db.tar.zst" ${REPODIR}/${PKG}/${PKG_FULLNAME}*.pkg.tar.zst
        fi
      else
        echo -e "${YELLOW}==> WARN:${WHITE} Requested build of ${KERNEL_NAME}/${PKG_FULLNAME} but no PKGBUILD file exists. Skipping ....${NOCOLOR}\n"
      fi
    fi
  done
}

build_sources() {
  unset PKG_KERNEL_NAME
  PKG_KERNEL_NAME=${KERNEL_NAME/_/-}

  for PKG in "${PKG_LIST[@]}"; do
    if [[ $PKG = "std" ]]; then
      PKG_FULLNAME="zfs-${PKG_KERNEL_NAME}"
    else
      PKG_FULLNAME="zfs-${PKG_KERNEL_NAME}-${PKG}"
    fi

    PKG_FULLNAME=${PKG_FULLNAME/--/-}

    if ! [ -d "${BINDDIR}/packages/${KERNEL_NAME}/${PKG_FULLNAME}" ]; then
      echo -e "${YELLOW}==> WARN:${WHITE} Requested source build of ${KERNEL_NAME}/${PKG_FULLNAME} but directory does not exist. Skipping ...${NOCOLOR}\n"
    else
      cd "${BINDDIR}/packages/${KERNEL_NAME}/${PKG_FULLNAME}"
      if [[ -f ./PKGBUILD ]]; then
        echo -e "${BLUE}==>${WHITE} Building source for ${KERNEL_NAME}/${PKG_FULLNAME}...${NOCOLOR}\n"
	
        makechrootpkg -c -u -U ${BUILD_USER} -r ${CHROOTDIR} -d ${REPODIR} -- --printsrcinfo > .SRCINFO || true
	makechrootpkg -c -u -U ${BUILD_USER} -r ${CHROOTDIR} -d ${REPODIR} -- --source || true

      else
        echo -e "${YELLOW}==> WARN:${WHITE} Requested source build of ${KERNEL_NAME}/${PKG_FULLNAME} but no PKGBUILD file exists. Skipping ....${NOCOLOR}\n"
      fi
    fi
  done
}


if [[ ${EUID} -ne 0 ]]; then
  printf "${RED}==> ERROR:${WHITE} This script must be run as root.\n${NOCOLOR}Aborting.\n" 1>&2
  exit 155;
fi

main "$@"; exit
