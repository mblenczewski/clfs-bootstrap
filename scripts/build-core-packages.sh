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
### - CLFS_CROSS_NAME       : Name of the cross-toolchain root
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


## TODO: get libressl to cross compile and ignore /usr/lib/libgcc in favour
##       of libgcc in sysroot
LIBRESSL () {
	./configure \
		--prefix=/usr \
		--build=${CLFS_HOST} \
		--host=${CLFS_TARGET} \
		--enable-shared \
		--with-openssldir=/etc/ssl

	make && make DESTDIR=${CLFS_ROOT} install
}
#EXTRACT "LIBRESSL" LIBRESSL "base-pkg-libressl"


BINUTILS () {
	mkdir -v binutils-build
	cd binutils-build

	../configure \
		--prefix=/usr \
		--with-build-sysroot=${CLFS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_TARGET} \
		--target=${CLFS_TARGET} \
		--enable-gold \
		--enable-ld=default \
		--enable-plugins \
		--enable-shared \
		--disable-multilib \
		--disable-nls \
		--disable-werror \
		--with-system-zlib \
		${COMMON_BINUTILS_OPTS[@]}

	make tooldir=/usr
	make tooldir=/usr DESTDIR=${CLFS_ROOT} install
}
#EXTRACT "BINUTILS" BINUTILS "core-pkg-binutils"


GCC () {
	mkdir -v gcc-build
	cd gcc-build

	../configure \
		--prefix=/usr \
		--with-build-sysroot=${CLFS_ROOT} \
		--build=${CLFS_HOST} \
		--host=${CLFS_TARGET} \
		--target=${CLFS_TARGET} \
		${CLFS_GCC_OPTS} \
		--enable-languages=c,c++ \
		--disable-multilib \
		--disable-nls \
		--with-system-zlib \
		${COMMON_GCC_OPTS[@]}

	make
	make DESTDIR=${CLFS_ROOT} install
	rm -rf ${CLFS_ROOT}/usr/lib/gcc/$(${CLFS_TARGET}-gcc -dumpmachine)/${GCC_VER}/include-fixed/bits

	ln -sv ../usr/bin/cpp ${CLFS_ROOT}/lib

	install -v -dm755 ${CLFS_ROOT}/usr/lib/bfd-plugins
	ln -sfv ../../libexec/gcc/$(${CLFS_TARGET}-gcc -dumpmachine)/${GCC_VER}/liblto_plugin.so \
		${CLFS_ROOT}/usr/lib/bfd-plugins

	mkdir -pv ${CLFS_ROOT}/usr/share/gdb/auto-load/usr/lib
	mv -v ${CLFS_ROOT}/usr/lib/*gdb.py ${CLFS_ROOT}/usr/share/gdb/auto-load/usr/lib
}
#EXTRACT "GCC" GCC "core-pkg-gcc"


BUSYBOX () {
        make distclean

        make ARCH="${CLFS_ARCH}" defconfig

        make ARCH="${CLFS_ARCH}" CROSS_COMPILE="${CLFS_TARGET}-" && \
        make ARCH="${CLFS_ARCH}" CROSS_COMPILE="${CLFS_TARGET}-" CONFIG_PREFIX="${CLFS_ROOT}" install

        #### For building the linux kernel with modules
        cp -v examples/depmod.pl ${CLFS_ROOT}/bin
        chmod -v 755 ${CLFS_ROOT}/bin/depmod.pl
}
EXTRACT "BUSYBOX" BUSYBOX "core-pkg-busybox"


## Creating /etc/profile
cat > ${CLFS_ROOT}/etc/profile <<'EOF'
# /etc/profile

# Set the initial path
export PATH=/bin:/usr/bin

if [ `id -u` -eq 0 ] ; then
	export PATH=/bin:/sbin:/usr/bin:/usr/sbin
	unset HISTFILE
fi

# Setup some environment variables.
export USER=`id -un`
export LOGNAME=$USER
export HOSTNAME=`/bin/hostname`
export HISTSIZE=1000
export HISTFILESIZE=1000
export PAGER='/bin/more '
export EDITOR='/bin/vi'

COMMON_FLAGS="-O2 -march=native -mtune=native -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"

MAKEFLAGS="-j$(nproc)"

# End /etc/profile
EOF


IANA_ETC () {
        cp protocols services ${CLFS_ROOT}/etc
}
EXTRACT "IANA_ETC" IANA_ETC "core-pkg-iana-etc"


## Setting hostname
echo ${CLFS_HOSTNAME} > ${CLFS_ROOT}/etc/hostname


## Customising /etc/hosts
cat > ${CLFS_ROOT}/etc/hosts <<'EOF'
# Begin /etc/hosts (no network card version)

127.0.0.1 localhost
::1 localhost

# End /etc/hosts (no network card version)
EOF


## Configuring the network script
mkdir -pv ${CLFS_ROOT}/etc/network/if-{post-{up,down},pre-{up,down},up,down}.d
mkdir -pv ${CLFS_ROOT}/usr/share/udhcpc

cat > ${CLFS_ROOT}/etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback
iface lo inet6 loopback

auto eth0
iface eth0 inet dhcp
iface eth0 inet6 dhcp
EOF

cat > ${CLFS_ROOT}/usr/share/udhcpc/default.script <<'EOF'
#!/bin/sh
# udhcpc Interface Configuration
# Based on http://lists.debian.org/debian-boot/2002/11/msg00500.html
# udhcpc script edited by Tim Riker <Tim@Rikers.org>

[ -z "$1" ] && echo "Error: should be called from udhcpc" && exit 1

RESOLV_CONF="/etc/resolv.conf"
[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
[ -n "$subnet" ] && NETMASK="netmask $subnet"

case "$1" in
	deconfig)
		/sbin/ifconfig $interface 0.0.0.0
		;;

	renew|bound)
		/sbin/ifconfig $interface $ip $BROADCAST $NETMASK

		if [ -n "$router" ] ; then
			while route del default gw 0.0.0.0 dev $interface ; do
				true
			done

			for i in $router ; do
				route add default gw $i dev $interface
			done
		fi

		echo -n > $RESOLV_CONF
		[ -n "$domain" ] && echo search $domain >> $RESOLV_CONF
		for i in $dns ; do
			echo nameserver $i >> $RESOLV_CONF
		done
		;;
esac

exit 0
EOF

chmod +x ${CLFS_ROOT}/usr/share/udhcpc/default.script

