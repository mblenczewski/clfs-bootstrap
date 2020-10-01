#!/bin/sh

################################################################################
### Defined Variables:
### - CLFS                  : Root folder for entire CLFS build
### - CLFS_BUILD            : Final tarball output directory
### - CLFS_CONFIGS          : Additional configuration files for CLFS packages
### - CLFS_LOGS             : Package build log root
### - CLFS_SCRIPTS          : Build script root
### - CLFS_SOURCES          : Package source root
### ----------------------------------------------------------------------------
### - CLFS_ROOT             : Root folder for cross-compiled system
### - CLFS_BOOT_ROOT        : Root folder for boot-required binaries
### - CLFS_CROSS_ROOT       : Root folder for cross-toolchain
### - CLFS_CROSS_SYSROOT    : Sysroot for cross-toolchain
################################################################################

source ~/.bashrc

## Netplug
NETPLUG () {
    patch -Np1 -i ../netplug-1.2.9.2-fixes-1.patch

    make && make DESTDIR=${CLFS_ROOT} install
}
EXTRACT "NETPLUG" NETPLUG "extra-pkg-netplug"


## Wireless Tools
WIRELESS_TOOLS () {
    sed -i s/gcc/\$\{CLFS\_TARGET\}\-gcc/g Makefile
    sed -i s/\ ar/\ \$\{CLFS\_TARGET\}\-ar/g Makefile
    sed -i s/ranlib/\$\{CLFS\_TARGET\}\-ranlib/g Makefile

    make PREFIX=${CLFS_ROOT}/usr && make PREFIX=${CLFS_ROOT}/usr install
}
EXTRACT "WIRELESS_TOOLS" WIRELESS_TOOLS "extra-pkg-wireless-tools"


## Dropbear
DROPBEAR () {
    cp ${CLFS_CONFIGS}/dropbear_config.h localoptions.h

    ./configure \
        --prefix=${CLFS_ROOT}/usr \
        --build=${CLFS_HOST} \
        --host=${CLFS_TARGET}

    make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" && \
    make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" install

    install -dv ${CLFS_ROOT}/etc/dropbear
}
EXTRACT "DROPBEAR" DROPBEAR "extra-pkg-dropbear"

