# CLFS Stages

## Stage 0 : Initial Setup
Will be rebuilt every run

Process:
1. Select build target + configuration
2. Write out shell "includes" for exported variables (e.g. source archives, 
   versions, package names)
3. Create clfs build user + setup user bashrc with build configuration
4. Create clfs build directory + subdirectories
5. Pull in required sources and check source signatures
6. Copy required source package build scripts to build directory
6. Create linux standard filesystem layout for rootfs

### Build Directory Structure
```text
/clfs
  /sources  # contains all package sources
    /init  # contains the init scripts for the linux system
      ...
    /sysconf  # contains linux system configuration files (e.g. fstab, mdev)
      ...
    ...  # archives of all packages
  /configs  # contains all configuration files
    /pkg1  # contains configuration for package 1
      ...
    /pkg2  # contains configuration for package 2
      ...
    /pkg3  # contains configuration for package 3
      ...
    ...
  /stage1  # cross-toolchain
    f timestamp  # when this stage was last built
    f pkgindex  # the packages (+versions) last used to build this stage
    /pkgs  # contains symlinks to package sources
      l linux -> ../../sources/linux-x.y.z
      l libc -> ../../sources/musl-libc-x.y.z
      l libc++ -> ../../sources/gcc-x.y.z (/libstdc++?)
      l binutils -> ../../sources/binutils-x.y.z
      l gmp -> ../../sources/gmp-x.y.z
      l mpc -> ../../sources/mpc-x.y.z
      l mpfr -> ../../sources/mpfr-x.y.z
      l gcc -> ../../sources/gcc-x.y.z
    /conf  # contains symlinks to configuration files
      --
    /steps  # contains the steps for the build
      f 000-started.sh
      f 010-linux-headers.sh
      f 020-binutils-pass1.sh
      f 030-gcc-pass1.sh
      f 040-xtools-libc.sh
      f 050-xtools-libc++.sh
      f 060-binutils-pass2.sh
      f 070-gcc-pass2.sh
      f 999-finished.sh
    /build  # contains the output of the build
      --
  /stage2  # minimal build environment (cross-compiled using stage1)
    f timestamp
    f pkgindex
    /pkgs
      l linux -> ../../sources/linux-x.y.z
      l libc -> ../../sources/musl-libc-x.y.z
      l libc++ -> ../../sources/gcc-x.y.z (/libstdc++?)
      l zlib -> ../../sources/zlib-x.y.z
      l busybox (toybox?) -> ../../sources/busybox-x.y.z
      l iana -> ../../sources/iana-x.y.z
      l init -> ../../sources/init
      l sysconf -> ../../sources/sysconf
      l binutils -> ../../sources/binutils-x.y.z
      l gmp -> ../../sources/gmp-x.y.z
      l mpc -> ../../sources/mpc-x.y.z
      l mpfr -> ../../sources/mpfr-x.y.z
      l gcc -> ../../sources/gcc-x.y.z
      l make -> ../../sources/make-x.y.z
      l uboot -> ../../sources/uboot-x.y.z
    /conf
      l linux-config -> ../../configs/$TGT-linux-config
      l uboot-config -> ../../configs/$TGT-uboot-config
      l busybox-config -> ../../configs/$TGT-busybox-config
    /steps
      f 000-started.sh
      f 010-linux-headers.sh
      f 020-libc.sh
      f 030-libc++.sh
      f 040-zlib.sh
      f 050-busybox.sh
      f 060-sysconf.sh
      f 070-iana.sh
      f 080-init.sh
      f 090-binutils.sh
      f 100-gcc.sh
      f 110-make.sh
      f 120-linux.sh
      f 130-uboot.sh
      f 999-finished.sh
    /build
      --
  /stage3  # base system (natively compiled under stage2)
    f timestamp
    f pkgindex
    /pkgs
    /conf
    /steps
    /build
  /stage4  # custom system (natively compiled under stage3)
    f timestamp
    f pkgindex
    /pkgs
    /conf
    /steps
    /build
```

## Stage 1 : The Cross-Toolchain
Once built, can be reused until its scripts change or user requests rebuild

Required Packages:
1. Linux
2. Libc (musl)
3. Libc++ (libstdc++)
4. Binutils
5. GMP
6. MPC
7. MPFR
8. GCC

Process:
1. Extract linux headers for target arch
2. Build static no-libc x-binutils to build libc
3. Build static no-libc x-gcc to build libc
4. Build libc
5. Build libc++
6. Build final x-binutils
7. Build final x-gcc
8. Update build users .bashrc to register new tools

## Stage 2 : The Minimal Build Environment
Should be rebuilt every run

## Stage 3 : The Base System
Should be rebuilt every run

## Stage 4 : The Custom System
Should be rebuilt every run

