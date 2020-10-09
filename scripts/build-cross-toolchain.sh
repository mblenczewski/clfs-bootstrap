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
		--prefix=${CLFS_CROSS_SYSROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--target=${CLFS_TARGET} \
		--syslibdir=${CLFS_CROSS_SYSROOT}/lib

	make && make DESTDIR=${CLFS_CROSS_SYSROOT} install

	${CLFS_CROSS_ROOT}/libexec/gcc/${CLFS_TARGET}/${GCC_VER}/install-tools/mkheaders
}
EXTRACT "MUSL" MUSL "toolchain-musl-libc"


LIBSTDCXX_PASS1 () {
	mkdir -v libstdcxx-build
	cd libstdcxx-build

	../libstdc++-v3/configure \
		--prefix=${CLFS_CROSS_SYSROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--target=${CLFS_TARGET} \
		--disable-nls \
		--disable-multilib \
		--disable-libstdcxx-pch \
		--with-gxx-include-dir=${CLFS_CROSS_SYSROOT}/include/c++/${GCC_VER}

	make && make install
}
EXTRACT "GCC" LIBSTDCXX_PASS1 "toolchain-libstdc++-pass1"


M4 () {
	sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
	echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h

	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install
}
#EXTRACT "M4" M4 "toolchain-m4"


NCURSES () {
	sed -i s/mawk// configure

	mkdir ncurses-build
	pushd ncurses-build > /dev/null
		../configure
		make -C include
		make -C progs tic
	popd > /dev/null

	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--with-manpage-format=normal \
		--with-shared \
		--without-debuf \
		--without-ada \
		--without-normal \
		--with-widec

	make && make TIC_PATH=$(pwd)/ncurses-build/progs/tic install
	echo "INPUT(-lncursesw)" > ${CLFS_CROSS_ROOT}/lib/libncurses.so

	ln -sfv ../lib/$(readlink ${CLFS_CROSS_ROOT}/lib/libncursesw.so) ${CLFS_CROSS_ROOT}/lib/libncursesw.so
}
#EXTRACT "NCURSES" NCURSES "toolchain-ncurses"


BASH () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--without-bash-malloc

	make && make install

	ln -fsv bash ${CLFS_CROSS_ROOT}/bin/sh
}
#EXTRACT "BASH" BASH "toolchain-bash"


COREUTILS () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--enable-install-program=hostname \
		--enable-no-install-program=kill,uptime

	make && make install

	mv -v ${CLFS_CROSS_ROOT}/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} ${CLFS_CROSS_ROOT}/bin
	mv -v ${CLFS_CROSS_ROOT}/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} ${CLFS_CROSS_ROOT}/bin
	mv -v ${CLFS_CROSS_ROOT}/bin/{rmdir,stty,sync,true,uname} ${CLFS_CROSS_ROOT}/bin
	mv -v ${CLFS_CROSS_ROOT}/bin/{head,nice,sleep,touch} ${CLFS_CROSS_ROOT}/bin
	mv -v ${CLFS_CROSS_ROOT}/bin/chroot ${CLFS_CROSS_ROOT}/sbin
	mkdir -pv ${CLFS_CROSS_ROOT}/share/man/man8
	mv -v ${CLFS_CROSS_ROOT}/share/man/man1/chroot.1 ${CLFS_CROSS_ROOT}/share/man/man8/chroot.8
	sed -i 's/"1"/"8"/' ${CLFS_CROSS_ROOT}/share/man/man8/chroot.8
}
#EXTRACT "COREUTILS" COREUTILS "toolchain-coreutils"


DIFFUTILS () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install
}
#EXTRACT "DIFFUTILS" DIFFUTILS "toolchain-diffutils"


FILE () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install
}
#EXTRACT "FILE" FILE "toolchain-file"


FINDUTILS () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install

	sed -i 's|find:=${BINDIR}|find:=/${CLFS_CROSS_NAME}/bin|' ${CLFS_CROSS_ROOT}/bin/updatedb
}
#EXTRACT "FINDUTILS" FINDUTILS "toolchain-findutils"


GAWK () {
	sed -i 's/extras//' Makefile.in

	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install
}
#EXTRACT "GAWK" GAWK "toolchain-gawk"


GZIP () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install
}
#EXTRACT "GZIP" GZIP "toolchain-gzip"


MAKE () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--without-guile

	make && make install
}
#EXTRACT "MAKE" MAKE "toolchain-make"


PATCH () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install
}
#EXTRACT "PATCH" PATCH "toolchain-patch"


SED () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install
}
#EXTRACT "SED" SED "toolchain-sed"


TAR () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST}

	make && make install
}
#EXTRACT "TAR" TAR "toolchain-tar"


XZ () {
	./configure \
		--prefix=${CLFS_CROSS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_HOST} \
		--disable-static

	make && make install
}
#EXTRACT "XZ" XZ "toolchain-xz"


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
echo export CC=\""${CLFS_TARGET}-gcc\"" >> ~/.bashrc
echo export CXX=\""${CLFS_TARGET}-g++\"" >> ~/.bashrc
echo export AR=\""${CLFS_TARGET}-ar\"" >> ~/.bashrc
echo export AS=\""${CLFS_TARGET}-as\"" >> ~/.bashrc
echo export LD=\""${CLFS_TARGET}-ld\"" >> ~/.bashrc
echo export RANLIB=\""${CLFS_TARGET}-ranlib\"" >> ~/.bashrc
echo export READELF=\""${CLFS_TARGET}-readelf\"" >> ~/.bashrc
echo export STRIP=\""${CLFS_TARGET}-strip\"" >> ~/.bashrc
