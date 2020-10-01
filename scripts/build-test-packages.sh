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

## Installing libgcc
cp -v ${CLFS_CROSS_SYSROOT}/lib/libgcc_s.so.1 ${CLFS_ROOT}/usr/lib/
${CLFS_TARGET}-strip ${CLFS_ROOT}/lib/libgcc_s.so.1

ln -sfv ../usr/lib/libgcc_s.so.1 ${CLFS_ROOT}/lib/libgcc_s.so.1


## Linux API Headers
LINUX () {
    make mrproper
    
    make ARCH=${CLFS_ARCH} headers_check
    make ARCH=${CLFS_ARCH} headers
    
    find usr/include -name '.*' -delete
    rm usr/include/Makefile
    cp -r usr/include ${CLFS_ROOT}/usr
}
EXTRACT "LINUX" LINUX "test-pkg-linux-headers"


## Musl libc
MUSL () {
    ./configure \
        CROSS_COMPILE=${CLFS_TARGET}- \
        --prefix=${CLFS_ROOT}/usr \
        --build=${CLFS_HOST} \
        --host=${CLFS_TARGET} \
        --target=${CLFS_TARGET} \
        --syslibdir=${CLFS_ROOT}/lib \
        --enable-warnings

    make && make install

    ln -fsv ../usr/lib/libc.so ${CLFS_ROOT}/lib/ld-musl-*.so.1
}
EXTRACT "MUSL" MUSL "test-pkg-musl-libc"


## Libstdc++
LIBSTDCXX () {
    ln -s gthr-posix.h libgcc/gthr-default.h

    mkdir -v libstdcxx-build
    cd libstdcxx-build

    ../libstdc++-v3/configure \
        CXXFLAGS="-g -O2 -D_GNU_SOURCE" \
        --prefix=${CLFS_ROOT}/usr \
        --build=${CLFS_HOST} \
        --host=${CLFS_TARGET} \
        --target=${CLFS_TARGET} \
        --disable-nls \
        --disable-multilib

    make && make install
}
EXTRACT "GCC" LIBSTDCXX "test-pkg-libstdc++"


## Zlib
ZLIB () {
    ./configure \
        --prefix=${CLFS_ROOT}/usr \
        --const \
        --shared

    make && make install

    rm -v ${CLFS_ROOT}/usr/lib/libz.a
    mv -v ${CLFS_ROOT}/usr/lib/libz.so.* ${CLFS_ROOT}/lib
    ln -sfv ../../lib/$(readlink ${CLFS_ROOT}/usr/lib/libz.so) ${CLFS_ROOT}/usr/lib/libz.so
}
EXTRACT "ZLIB" ZLIB "test-pkg-zlib"


## Libressl
LIBRESSL () {
    ./configure \
        --prefix=${CLFS_ROOT}/usr \
        --build=${CLFS_HOST} \
        --host=${CLFS_TARGET} \
        --libdir=${CLFS_ROOT}/lib \
        --with-openssldir=${CLFS_ROOT}/etc/ssl

    make && make install
}
EXTRACT "LIBRESSL" LIBRESSL "test-pkg-libressl"


## Openssh
OPENSSH () {
    install -v -m700 -d ${CLFS_ROOT}/var/lib/sshd

    ./configure \
        --prefix=${CLFS_ROOT}/usr \
        --build=${CLFS_HOST} \
        --host=${CLFS_TARGET} \
        --sysconfdir=/etc/ssh \
        --with-md5-passwords \
        --with-privsep-path=/var/lib/sshd

    make && make install

    install -v -m755 contrib/ssh-copy-id ${CLFS_ROOT}/usr/bin
    install -v -m644 contrib/ssh-copy-id.1 ${CLFS_ROOT}/usr/share/man/man1
    install -v -m755 -d ${CLFS_ROOT}/usr/share/doc/openssh-${OPENSSH_VER}
    install -v -m644 INSTALL LICENCE OVERVIEW README* ${CLFS_ROOT}/usr/share/doc/openssh-${OPENSSH_VER}
}
EXTRACT "OPENSSH" OPENSSH "test-pkg-openssh"
