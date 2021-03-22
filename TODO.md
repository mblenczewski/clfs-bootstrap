# TODO

1. Reorganise into a gentoo-like "stage" structure:
   1. Stage 1 : Cross-compiler and build toolchain
   2. Stage 2 : Bootstrap system containing native toolchain (linux, musl-libc, busybox/toybox, binutils, gcc)
   3. Stage 3 : Final "base" system built using the previous stage 2 system in a virtual machine environment (or on native host)
   4. Stage 4 : Additional packages built using the previous stage 3 system in a virtual machine environment (or on native host)

2. Provide a Makefile wrapper around the build scripts
3. Implement QEMU (+KVM) to launch the built system and create the stage 3 from the stage 2
   - Ask on the #qemu irc channel for help with empty output
