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

## Creating passwd, group, and lastlog files
ln -svf ../proc/mounts ${CLFS_ROOT}/etc/mtab

cat > ${CLFS_ROOT}/etc/passwd <<'EOF'
root::0:0:root:/root:/bin/ash
EOF

cat > ${CLFS_ROOT}/etc/group <<'EOF'
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
EXTRACT "LINUX" LINUX "core-pkg-linux-headers"


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
EXTRACT "MUSL" MUSL "core-pkg-musl-libc"


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
EXTRACT "GCC" LIBSTDCXX "core-pkg-libstdc++"


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
EXTRACT "ZLIB" ZLIB "core-pkg-zlib"


## Bzpi2
BZIP2 () {
    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

    make -f Makefile-libbz2_so && make clean && \
    make && make PREFIX=${CLFS_ROOT}/usr install

    rm -v ${CLFS_ROOT}/usr/lib/libbz2.a
    cp -v bzip2-shared ${CLFS_ROOT}/bin/bzip2
    cp -av libbz2.so* ${CLFS_ROOT}/lib
    ln -fsv ../../lib/libbz2.so.1.0 ${CLFS_ROOT}/usr/lib/libbz2.so
    rm -v ${CLFS_ROOT}/usr/bin/{bunzip2,bzcat,bzip2}
    ln -sv bzip2 ${CLFS_ROOT}/bin/bunzip2
    ln -sv bzip2 ${CLFS_ROOT}/bin/bzcat
}
EXTRACT "BZIP2" BZIP2 "core-pkg-bzip2"


## Xz
XZ () {
    ./configure \
        --prefix=${CLFS_ROOT}/usr \
        --build=${CLFS_HOST} \
        --host=${CLFS_TARGET} \
        --disable-static \
        --docdir=${CLFS_ROOT}/usr/share/doc/xz-5.2.5

    make && make install

    mv -v ${CLFS_ROOT}/usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} ${CLFS_ROOT}/bin
    mv -v ${CLFS_ROOT}/usr/lib/liblzma.so.* ${CLFS_ROOT}/lib
    ln -svf ../../lib/$(readlink ${CLFS_ROOT}/usr/lib/liblzma.so) ${CLFS_ROOT}/usr/lib/liblzma.so
}
EXTRACT "XZ" XZ "core-pkg-xz"


## Zstd
ZSTD () {
    make && make prefix=${CLFS_ROOT}/usr install

    rm -v ${CLFS_ROOT}/usr/lib/libzstd.a
    mv -v ${CLFS_ROOT}/usr/lib/libzstd.so.* ${CLFS_ROOT}/lib
    ln -sfv ../../lib/$(readlink ${CLFS_ROOT}/usr/lib/libzstd.so) ${CLFS_ROOT}/usr/lib/libzstd.so
}
EXTRACT "ZSTD" ZSTD "core-pkg-zstd"


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
EXTRACT "LIBRESSL" LIBRESSL "core-pkg-libressl"


## Installing busybox
BUSYBOX () {
    make distclean

    make ARCH="${CLFS_ARCH}" defconfig

    sed -i 's/\(CONFIG_\)\(.*\)\(INETD\)\(.*\)=y/# \1\2\3\4 is not set/g' .config
    sed -i 's/\(CONFIG_IFPLUGD\)=y/# \1 is not set/' .config

    sed -i 's/\(CONFIG_FEATURE_WTMP\)=y/# \1 is not set/' .config
    sed -i 's/\(CONFIG_FEATURE_UTMP\)=y/# \1 is not set/' .config

    sed -i 's/\(CONFIG_UDPSVD\)=y/# \1 is not set/' .config
    sed -i 's/\(CONFIG_TCPSVD\)=y/# \1 is not set/' .config

    make ARCH="${CLFS_ARCH}" CROSS_COMPILE="${CLFS_TARGET}-" && \
    make ARCH="${CLFS_ARCH}" CROSS_COMPILE="${CLFS_TARGET}-" CONFIG_PREFIX="${CLFS_ROOT}" install

    #### For building the linux kernel with modules
    cp -v examples/depmod.pl ${CLFS_ROOT}/bin
    chmod -v 755 ${CLFS_ROOT}/bin/depmod.pl
}
EXTRACT "BUSYBOX" BUSYBOX "core-pkg-busybox"


## Installing iana-etc
IANA_ETC () {
    cp protocols services ${CLFS_ROOT}/etc
}
EXTRACT "IANA_ETC" IANA_ETC "core-pkg-iana-etc"


### Making the system bootable
## /etc/fstab file
cat > ${CLFS_ROOT}/etc/fstab <<'EOF'
# file-system  mount-point  type   options          dump  fsck
EOF


## Linux kernel
LINUX () {
    make mrproper

    cp ${CLFS_CONFIGS}/linux-kernel-config .config

    make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}- && \
    make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}- INSTALL_MOD_PATH=${CLFS_ROOT} modules_install

    cp arch/${CLFS_ARCH}/boot/zImage ${CLFS_BOOT_ROOT}
    for DTS in ${CLFS_ARCH_DTS_LIST[@]}
    do
        cp arch/${CLFS_ARCH}/boot/dts/$DTS ${CLFS_BOOT_ROOT}
    done
}
EXTRACT "LINUX" LINUX "linux-kernel"


## Das U-Boot
UBOOT () {
    make distclean

    cp ${CLFS_CONFIGS}/uboot-config .config

    make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}-

    cp u-boot.bin ${CLFS_BOOT_ROOT}
}
EXTRACT "UBOOT" UBOOT "uboot-bootloader"


## Bootscripts
BOOTSCRIPTS () {
    make DESTDIR=${CLFS_ROOT} install-bootscripts
    make DESTDIR=${CLFS_ROOT} install-dropbear
    make DESTDIR=${CLFS_ROOT} install-netplug
}
EXTRACT "BOOTSCRIPTS" BOOTSCRIPTS "core-pkg-bootscripts"


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

## Creating /etc/profile
cat > ${CLFS_ROOT}/etc/profile <<'EOF'
# /etc/profile

# Set the initial path
export PATH=/bin:/usr/bin

if [ `id -u` -eq 0 ] ; then
PATH=/bin:/sbin:/usr/bin:/usr/sbin
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

# End /etc/profile
EOF

## Creating /etc/inittab
cat > ${CLFS_ROOT}/etc/inittab <<'EOF'
# /etc/inittab

::sysinit:/etc/rc.d/startup

tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

# Put a getty on the serial line (for a terminal).  Uncomment this line if
# you're using a serial console on ttyS0, or uncomment and adjust it if using a
# serial console on a different serial port.
#::respawn:/sbin/getty -L ttyS0 115200 vt100

::shutdown:/etc/rc.d/shutdown
::ctrlaltdel:/sbin/reboot
EOF

## Setting hostname
echo ${CLFS_HOSTNAME} > ${CLFS_ROOT}/etc/HOSTNAME

## Customising /etc/hosts
cat > ${CLFS_ROOT}/etc/hosts <<'EOF'
# Begin /etc/hosts (no network card version)

127.0.0.1 localhost

# End /etc/hosts (no network card version)
EOF

## Configuring the network script
mkdir -pv ${CLFS_ROOT}/etc/network/if-{post-{up,down},pre-{up,down},up,down}.d
mkdir -pv ${CLFS_ROOT}/usr/share/udhcpc

cat > ${CLFS_ROOT}/etc/network/interfaces <<'EOF'
auto eth0
iface eth0 inet dhcp
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