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

## Binutils - Pass 1
BINUTILS_PASS1 () {
    mkdir -v binutils-build
    cd binutils-build

    ../configure \
        --prefix=${CLFS_CROSS_ROOT} \
        --with-sysroot=${CLFS_CROSS_SYSROOT} \
        --build=${CLFS_HOST} \
        --host=${CLFS_HOST} \
        --target=${CLFS_TARGET} \
        --disable-nls \
        --disable-shared \
        --disable-multilib \
        --disable-werror
    
    make && make install
}
EXTRACT "BINUTILS" BINUTILS_PASS1 "toolchain-binutils-pass1"


## GCC - Pass 1
GCC_PASS1 () {
    tar xf ../${MPFR_ARCHIVE}
    mv -v ${MPFR_DIR} mpfr
    tar xf ../${GMP_ARCHIVE}
    mv -v ${GMP_DIR} gmp
    tar xf ../${MPC_ARCHIVE}
    mv -v ${MPC_DIR} mpc

    mkdir -v gcc-build
    cd gcc-build

    ../configure \
        --prefix=${CLFS_CROSS_ROOT} \
        --with-sysroot=${CLFS_CROSS_SYSROOT} \
        --build=${CLFS_HOST} \
        --host=${CLFS_HOST} \
        --target=${CLFS_TARGET} \
        --with-newlib \
        --without-headers \
        --enable-initfini-array \
        --disable-nls \
        --disable-shared \
        --disable-multilib \
        --disable-decimal-float \
        --disable-threads \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libsanitizer \
        --disable-libssp \
        --disable-libvtv \
        --disable-libstdcxx \
        --enable-languages=c,c++ \
        --with-arch=${CLFS_ARM_ARCH} \
        --with-tune=${CLFS_GCC_TUNE} \
        ${CLFS_GCC_FLOAT_OPT} ${CLFS_GCC_FPU_OPT}

    make all-gcc all-target-libgcc && make install-gcc install-target-libgcc

    cd ..
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        `dirname $(${CLFS_TARGET}-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
}
EXTRACT "GCC" GCC_PASS1 "toolchain-gcc-pass1"


## Linux API Headers
LINUX () {
    make mrproper
    
    make ARCH=${CLFS_ARCH} headers_check
    make ARCH=${CLFS_ARCH} headers
    
    find usr/include -name '.*' -delete
    rm usr/include/Makefile
    cp -r usr/include ${CLFS_CROSS_SYSROOT}
}
EXTRACT "LINUX" LINUX "toolchain-linux-headers"


## Musl libc
MUSL () {
    ./configure \
        CROSS_COMPILE=${CLFS_TARGET}- \
        --prefix=/ \
        --build=${CLFS_HOST} \
        --host=${CLFS_HOST} \
        --target=${CLFS_TARGET}

    make && make DESTDIR=${CLFS_CROSS_SYSROOT} install

    ${CLFS_CROSS_ROOT}/libexec/gcc/${CLFS_TARGET}/${GCC_VER}/install-tools/mkheaders
}
EXTRACT "MUSL" MUSL "toolchain-musl-libc"


## Libstdc++ - Pass 1
LIBSTDCXX_PASS1 () {
    mkdir -v libstdcxx-build
    cd libstdcxx-build

    ../libstdc++-v3/configure \
        --prefix=/ \
        --build=${CLFS_HOST} \
        --host=${CLFS_HOST} \
        --target=${CLFS_TARGET} \
        --disable-nls \
        --disable-multilib \
        --disable-libstdcxx-pch \
        --with-gxx-include-dir=${CLFS_CROSS_SYSROOT}/include/c++/${GCC_VER}

    make && make DESTDIR=${CLFS_CROSS_SYSROOT} install
}
EXTRACT "GCC" LIBSTDCXX_PASS1 "toolchain-libstdc++-pass1"


## Binutils - Pass 2
BINUTILS_PASS2 () {
    mkdir -v binutils-build
    cd binutils-build

    ../configure \
        --prefix=${CLFS_CROSS_ROOT} \
        --with-sysroot=${CLFS_ROOT} \
        --with-build-sysroot=${CLFS_CROSS_SYSROOT} \
        --build=${CLFS_HOST} \
        --host=${CLFS_HOST} \
        --target=${CLFS_TARGET} \
        --disable-nls \
        --enable-shared \
        --disable-multilib \
        --disable-werror
    
    make && make install
}
EXTRACT "BINUTILS" BINUTILS_PASS2 "toolchain-binutils-pass2"


## GCC - Pass 2
GCC_PASS2 () {
    tar xf ../${MPFR_ARCHIVE}
    mv -v ${MPFR_DIR} mpfr
    tar xf ../${GMP_ARCHIVE}
    mv -v ${GMP_DIR} gmp
    tar xf ../${MPC_ARCHIVE}
    mv -v ${MPC_DIR} mpc

    mkdir -v gcc-build
    cd gcc-build

    mkdir -pv ${CLFS_TARGET}/libgcc
    ln -s ../../../libgcc/gthr-posix.h ${CLFS_TARGET}/libgcc/gthr-default.h

    ../configure \
        --prefix=${CLFS_CROSS_ROOT} \
        --with-sysroot=${CLFS_ROOT} \
        --with-build-sysroot=${CLFS_CROSS_SYSROOT} \
        --build=${CLFS_HOST} \
        --host=${CLFS_HOST} \
        CC_FOR_TARGET=${CLFS_TARGET}-gcc \
        --target=${CLFS_TARGET} \
        --enable-initfini-array \
        --disable-nls \
        --disable-multilib \
        --disable-libsanitizer \
        --enable-languages=c,c++ \
        --with-arch=${CLFS_ARM_ARCH} \
        --with-tune=${CLFS_GCC_TUNE} \
        ${CLFS_GCC_FLOAT_OPT} ${CLFS_GCC_FPU_OPT}

    make && make install
}
EXTRACT "GCC" GCC_PASS2 "toolchain-gcc-pass2"


## Setting toolchain variables
echo export CC=\""${CLFS_TARGET}-gcc sysroot=${CLFS_ROOT}\"" >> ~/.bashrc
echo export CXX=\""${CLFS_TARGET}-g++ sysroot=${CLFS_ROOT}\"" >> ~/.bashrc
echo export AR=\""${CLFS_TARGET}-ar\"" >> ~/.bashrc
echo export AS=\""${CLFS_TARGET}-as\"" >> ~/.bashrc
echo export LD=\""${CLFS_TARGET}-ld sysroot=${CLFS_ROOT}\"" >> ~/.bashrc
echo export RANLIB=\""${CLFS_TARGET}-ranlib\"" >> ~/.bashrc
echo export READELF=\""${CLFS_TARGET}-readelf\"" >> ~/.bashrc
echo export STRIP=\""${CLFS_TARGET}-strip\"" >> ~/.bashrc
