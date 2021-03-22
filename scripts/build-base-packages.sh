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


## Allows logging in as root without password
cat > ${CLFS_ROOT}/etc/passwd << "EOF"
root::0:0:root:/root:/bin/ash
EOF

## Creating the group,passwd, and lastlog files
cat > ${CLFS_ROOT}/etc/group << "EOF"
root:x:0:
bin:x:1:
sys:x:2:
kmem:x:3:
tty:x:4:
tape:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
EOF

touch ${CLFS_ROOT}/var/log/lastlog
chmod -v 664 ${CLFS_ROOT}/var/log/lastlog


## Copying libgcc from the xgcc we built earlier. This is necessary as gcc can
## emit calls to this shared library whenever it sees fit.
cp -v ${CLFS_CROSS_SYSROOT}/lib/libgcc_s.so.1 ${CLFS_ROOT}/usr/lib/
ln -fsv ../usr/lib/libgcc_s.so.1 ${CLFS_ROOT}/lib/libgcc_s.so.1
${CLFS_TARGET}-strip ${CLFS_ROOT}/lib/libgcc_s.so.1


LINUX () {
	make mrproper

	make ARCH=${CLFS_ARCH} headers_check
	make ARCH=${CLFS_ARCH} headers

	find usr/include -name '.*' -delete
	rm usr/include/Makefile
	cp -r usr/include ${CLFS_ROOT}/usr
}
EXTRACT "LINUX" LINUX "base-pkg-linux-headers"


MUSL () {
	./configure \
		CROSS_COMPILE=${CLFS_TARGET}- \
		--prefix=/usr \
		--build=${CLFS_HOST} \
		--host=${CLFS_TARGET} \
		--target=${CLFS_TARGET} \
		--enable-warnings \
		--enable-optimize

	make && make DESTDIR=${CLFS_ROOT} install

	ln -fsv ../usr/lib/libc.so ${CLFS_ROOT}/lib/ld-musl-*.so.1
}
EXTRACT "MUSL" MUSL "base-pkg-musl-libc"


LIBSTDCXX () {
	ln -s gthr-posix.h libgcc/gthr-default.h

	mkdir -v libstdcxx-build
	cd libstdcxx-build

	../libstdc++-v3/configure \
		CXXFLAGS="-g -O2 -D_GNU_SOURCE" \
		--prefix=/usr \
		--build=${CLFS_HOST} \
		--host=${CLFS_TARGET} \
		--target=${CLFS_TARGET} \
		--disable-multilib \
		--disable-nls \
		--disable-static

	make && make DESTDIR=${CLFS_ROOT} install
}
EXTRACT "GCC" LIBSTDCXX "base-pkg-libstdc++"


ZLIB () {
	./configure \
		--prefix=/usr \
		--const \
		--shared

	make && make DESTDIR=${CLFS_ROOT} install

	rm -v ${CLFS_ROOT}/usr/lib/libz.a
	mv -v ${CLFS_ROOT}/usr/lib/libz.so.* ${CLFS_ROOT}/lib
	ln -sfv ../../lib/$(readlink ${CLFS_ROOT}/usr/lib/libz.so) ${CLFS_ROOT}/usr/lib/libz.so
}
EXTRACT "ZLIB" ZLIB "base-pkg-zlib"


LINUX () {
	make mrproper

	cp ${CLFS_CONFIGS}/${CLFS_ARCH}-kernel-config .config

	make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}- && \
	make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}- INSTALL_MOD_PATH=${CLFS_ROOT} modules_install

	cp arch/${CLFS_ARCH}/boot/$CLFS_KERNEL ${CLFS_BOOT_ROOT}
	for DTS in ${CLFS_DTS_LIST[@]}; do
		cp arch/${CLFS_ARCH}/boot/dts/$DTS ${CLFS_BOOT_ROOT}
	done
}
EXTRACT "LINUX" LINUX "boot-pkg-linux"


UBOOT () {
	make distclean

	cp ${CLFS_CONFIGS}/uboot-config .config

	make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}-

	cp u-boot.bin ${CLFS_BOOT_ROOT}
}
EXTRACT "UBOOT" UBOOT "boot-pkg-uboot"


## Installing bootscripts
cd ${CLFS_BOOTSCRIPTS}

make DESTDIR=${CLFS_ROOT} install-bootscripts install-dropbear

cd ${CLFS_SOURCES}


## Creating /etc/fstab file
cat > ${CLFS_ROOT}/etc/fstab <<'EOF'
# file-system  mount-point  type   options          dump  fsck
EOF


## Creating /etc/inittab
cat > ${CLFS_ROOT}/etc/inittab <<'EOF'
# /etc/inittab

::sysinit:/etc/rc.d/startup

tty1::respawn:/sbin/getty 38400 tty1
#tty2::respawn:/sbin/getty 38400 tty2
#tty3::respawn:/sbin/getty 38400 tty3
#tty4::respawn:/sbin/getty 38400 tty4
#tty5::respawn:/sbin/getty 38400 tty5
#tty6::respawn:/sbin/getty 38400 tty6

::shutdown:/etc/rc.d/shutdown
::ctrlaltdel:/sbin/reboot
EOF


## Configuring mdev
cat > ${CLFS_ROOT}/etc/mdev.conf<<'EOF'
# /etc/mdev/conf

# Devices:
# Syntax: %s %d:%d %s
# devices user:group mode

# null does already exist; therefore ownership has to be changed with command
null    root:root 0666  @chmod 666 $MDEV
zero    root:root 0666
grsec   root:root 0660
full    root:root 0666

random  root:root 0666
urandom root:root 0444
hwrandom root:root 0660

# console does already exist; therefore ownership has to be changed with command
#console        root:tty 0600   @chmod 600 $MDEV && mkdir -p vc && ln -sf ../$MDEV vc/0
console root:tty 0600 @mkdir -pm 755 fd && cd fd && for x in 0 1 2 3 ; do ln -sf /proc/self/fd/$x $x; done

fd0     root:floppy 0660
kmem    root:root 0640
mem     root:root 0640
port    root:root 0640
ptmx    root:tty 0666

# ram.*
ram([0-9]*)     root:disk 0660 >rd/%1
loop([0-9]+)    root:disk 0660 >loop/%1
sd[a-z].*       root:disk 0660 */lib/mdev/usbdisk_link
hd[a-z][0-9]*   root:disk 0660 */lib/mdev/ide_links
md[0-9]         root:disk 0660

tty             root:tty 0666
tty[0-9]        root:root 0600
tty[0-9][0-9]   root:tty 0660
ttyS[0-9]*      root:tty 0660
pty.*           root:tty 0660
vcs[0-9]*       root:tty 0660
vcsa[0-9]*      root:tty 0660

ttyLTM[0-9]     root:dialout 0660 @ln -sf $MDEV modem
ttySHSF[0-9]    root:dialout 0660 @ln -sf $MDEV modem
slamr           root:dialout 0660 @ln -sf $MDEV slamr0
slusb           root:dialout 0660 @ln -sf $MDEV slusb0
fuse            root:root  0666

# dri device
card[0-9]       root:video 0660 =dri/

# alsa sound devices and audio stuff
pcm.*           root:audio 0660 =snd/
control.*       root:audio 0660 =snd/
midi.*          root:audio 0660 =snd/
seq             root:audio 0660 =snd/
timer           root:audio 0660 =snd/

adsp            root:audio 0660 >sound/
audio           root:audio 0660 >sound/
dsp             root:audio 0660 >sound/
mixer           root:audio 0660 >sound/
sequencer.*     root:audio 0660 >sound/

# misc stuff
agpgart         root:root 0660  >misc/
psaux           root:root 0660  >misc/
rtc             root:root 0664  >misc/

# input stuff
event[0-9]+     root:root 0640 =input/
mice            root:root 0640 =input/
mouse[0-9]      root:root 0640 =input/
ts[0-9]         root:root 0600 =input/

# v4l stuff
vbi[0-9]        root:video 0660 >v4l/
video[0-9]      root:video 0660 >v4l/

# dvb stuff
dvb.*           root:video 0660 */lib/mdev/dvbdev

# load drivers for usb devices
usbdev[0-9].[0-9]       root:root 0660 */lib/mdev/usbdev
usbdev[0-9].[0-9]_.*    root:root 0660

# net devices
tun[0-9]*       root:root 0600 =net/
tap[0-9]*       root:root 0600 =net/

# zaptel devices
zap(.*)         root:dialout 0660 =zap/%1
dahdi!(.*)      root:dialout 0660 =dahdi/%1

# raid controllers
cciss!(.*)      root:disk 0660 =cciss/%1
ida!(.*)        root:disk 0660 =ida/%1
rd!(.*)         root:disk 0660 =rd/%1

sr[0-9]         root:cdrom 0660 @ln -sf $MDEV cdrom

# hpilo
hpilo!(.*)      root:root 0660 =hpilo/%1

# xen stuff
xvd[a-z]        root:root 0660 */lib/mdev/xvd_links
EOF

