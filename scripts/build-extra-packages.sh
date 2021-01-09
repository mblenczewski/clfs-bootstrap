#!/bin/bash

################################################################################
### Defined Variables:
### - CLFS                  : Root folder for CLFS build, holds final tarballs
### - CLFS_BOOTSCRIPTS      : Root folder for CLFS bootscripts
### - CLFS_CONFIGS          : Additional configuration files for CLFS packages
### - CLFS_LOGS             : Package build log root
### - CLFS_SCRIPTS          : Build script root
### - CLFS_SOURCES          : Package source root
### ----------------------------------------------------------------------------
### - CLFS_ROOT             : Root folder for cross-compiled system
### - CLFS_BOOT_ROOT        : Root folder for boot-required binaries
### - CLFS_CROSS_NAME       : Name of cross-toolchain root
### - CLFS_CROSS_ROOT       : Root folder for cross-toolchain
### - CLFS_CROSS_SYSROOT    : Sysroot for cross-toolchain
################################################################################

source ~/.bashrc


WIRELESS_TOOLS () {
	sed -i s/gcc/\$\{CLFS\_TARGET\}\-gcc/g Makefile
	sed -i s/\ ar/\ \$\{CLFS\_TARGET\}\-ar/g Makefile
	sed -i s/ranlib/\$\{CLFS\_TARGET\}\-ranlib/g Makefile

	make PREFIX=${CLFS_ROOT}/usr && make PREFIX=${CLFS_ROOT}/usr install
}
EXTRACT "WIRELESS_TOOLS" WIRELESS_TOOLS "extra-pkg-wireless-tools"


DROPBEAR () {
	sed -i 's/.*mandir.*//g' Makefile.in

	./configure \
		--prefix=/usr \
		--build=${CLFS_HOST} \
		--host=${CLFS_TARGET}

	cp ${CLFS_CONFIGS}/dropbear_config.h localoptions.h

	make MULTI=1 PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" && \
	make MULTI=1 PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" DESTDIR=${CLFS_ROOT} install

	install -dv ${CLFS_ROOT}/etc/dropbear
}
EXTRACT "DROPBEAR" DROPBEAR "extra-pkg-dropbear"

