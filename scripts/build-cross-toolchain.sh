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
### - CLFS_CROSS_NAME       : Name of cross-toolchain root
### - CLFS_CROSS_ROOT       : Root folder for cross-toolchain
### - CLFS_CROSS_SYSROOT    : Sysroot for cross-toolchain
################################################################################

source ~/.bashrc


COMMON_BINUTILS_OPTS=(\
	--enable-deterministic-archives \
	--disable-separate-code \
)


COMMON_GCC_OPTS=(\
	--enable-libstdcxx-time=rt \
	--disable-assembly \
	--disable-bootstrap \
	--disable-gnu-indirect-function \
	--disable-libmpx \
	--disable-libmudflap \
	--disable-libsanitizer \
)


BINUTILS_PASS1 () {
	mkdir -v binutils-build
	cd binutils-build

	../configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--with-sysroot=${CLFS_CROSS_SYSROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--target=${CLFS_TARGET} \
		--disable-multilib \
		--disable-nls \
		--disable-shared \
		--disable-werror \
		${COMMON_BINUTILS_OPTS[@]}

	make && make install
}
EXTRACT "BINUTILS" BINUTILS_PASS1 "toolchain-binutils-pass1"


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
		--with-arch=${CLFS_GCC_ARCH} \
		--with-tune=${CLFS_GCC_TUNE} \
		--with-newlib \
		--without-headers \
		--enable-initfini-array \
		--enable-languages=c,c++ \
		--disable-decimal-float \
		--disable-libatomic \
		--disable-libgomp \
		--disable-libquadmath \
		--disable-libssp \
		--disable-libstdcxx \
		--disable-libvtv \
		--disable-multilib \
		--disable-nls \
		--disable-shared \
		--disable-threads \
		${COMMON_GCC_OPTS[@]} \
		${CLFS_GCC_FLOAT_OPT} ${CLFS_GCC_FPU_OPT}

	make all-gcc all-target-libgcc && make install-gcc install-target-libgcc

	cd ..
	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        	`dirname $(${CLFS_TARGET}-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
}
EXTRACT "GCC" GCC_PASS1 "toolchain-gcc-pass1"


LINUX () {
	make mrproper

	make ARCH=${CLFS_ARCH} headers_check
	make ARCH=${CLFS_ARCH} headers

	find usr/include -name '.*' -delete
	rm usr/include/Makefile
	cp -r usr/include ${CLFS_CROSS_SYSROOT}
}
EXTRACT "LINUX" LINUX "toolchain-linux-headers"


MUSL () {
	./configure \
		CROSS_COMPILE=${CLFS_TARGET}- \
		--prefix=/ \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--target=${CLFS_TARGET}

	make && make DESTDIR=${CLFS_CROSS_SYSROOT} install

	ln -fsv libc.so ${CLFS_CROSS_SYSROOT}/lib/ld-musl-*.so.1

	${CLFS_CROSS_ROOT}/libexec/gcc/${CLFS_TARGET}/${GCC_VER}/install-tools/mkheaders
}
EXTRACT "MUSL" MUSL "toolchain-musl-libc"


LIBSTDCXX_PASS1 () {
	mkdir -v libstdcxx-build
	cd libstdcxx-build

	../libstdc++-v3/configure \
		--prefix=/ \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--target=${CLFS_TARGET} \
		--with-gxx-include-dir=${CLFS_CROSS_SYSROOT}/include/c++/${GCC_VER} \
		--disable-libstdcxx-pch \
		--disable-multilib \
		--disable-nls

	make && make DESTDIR=${CLFS_CROSS_SYSROOT} install
}
EXTRACT "GCC" LIBSTDCXX_PASS1 "toolchain-libstdc++-pass1"


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
		--enable-shared \
		--disable-multilib \
		--disable-nls \
		--disable-werror \
		${COMMON_BINUTILS_OPTS[@]}

	make && make install
}
EXTRACT "BINUTILS" BINUTILS_PASS2 "toolchain-binutils-pass2"


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
		--with-arch=${CLFS_GCC_ARCH} \
		--with-tune=${CLFS_GCC_TUNE} \
		--enable-initfini-array \
		--enable-languages=c,c++ \
		--enable-shared \
		--enable-tls \
		--disable-multilib \
		--disable-nls \
		${COMMON_GCC_OPTS[@]} \
		${CLFS_GCC_FLOAT_OPT} ${CLFS_GCC_FPU_OPT}

	make && make install
}
EXTRACT "GCC" GCC_PASS2 "toolchain-gcc-pass2"


## Setting toolchain variables
echo export CC=\""${CLFS_TARGET}-gcc\"" >> ~/.bashrc
echo export CXX=\""${CLFS_TARGET}-g++\"" >> ~/.bashrc
echo export AR=\""${CLFS_TARGET}-ar\"" >> ~/.bashrc
echo export AS=\""${CLFS_TARGET}-as\"" >> ~/.bashrc
echo export LD=\""${CLFS_TARGET}-ld\"" >> ~/.bashrc
echo export RANLIB=\""${CLFS_TARGET}-ranlib\"" >> ~/.bashrc
echo export READELF=\""${CLFS_TARGET}-readelf\"" >> ~/.bashrc
echo export STRIP=\""${CLFS_TARGET}-strip\"" >> ~/.bashrc

