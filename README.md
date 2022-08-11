# BOOTSECTORS

This repository contains programs that can boot an IBM-compatible PC.
Such programs are 512 bytes or less of 8086 machine code,
whose last two bytes are a magic number denoting bootability.
They make up the master boot record (MBR) of a legacy-style disk.

The included Makefile (written for [`bmake`][1])
will by default create two files for each program.
First there is the 512-byte MBR image itself, whose suffix is `.bin`.
Then there is a 160K floppy image, suffixed by `.img`,
suitable for booting emulated PCs through [86Box][2] or similar.

## Compilation
The following is written for a UNIX-like environment.
Ensure that `nasm` and `bmake` are installed, then invoke the latter:
```sh
bmake
```

## Caveats
Writing the resulting MBR file or disk image to a disk
will render inaccessible any data that the disk previously contained.
(The MBR contains both the boot program and the partition table.)

## Useful Links
* [x86 instruction set][3]
* [BIOS calls][4]
* [Keyboard scancodes][5]
* [Address space][6]



[1]: https://crufty.net/help/sjg/bmake.html
[2]: https://86Box.net
[3]: https://en.wikipedia.org/wiki/X86_instruction_listings
[4]: https://www.pcjs.org/documents/books/mspl13/msdos/encyclopedia/appendix-o/
[5]: https://www.ssterling.net/comp/scancodes/
[6]: https://wiki.osdev.org/Memory_Map_(x86)
