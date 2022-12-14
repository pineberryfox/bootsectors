.MAIN : all-images

.SUFFIXES :
.SUFFIXES : .s .bin .img .png

.s.bin:
	nasm -o "$@" -fbin -Wall "$<"
.bin.img:
	cat "$<" /dev/zero | dd of="$@" bs=512 count=320
.bin.png:
	qrencode -o "$@" -8 < "$<"

.PHONY : all-images
all-images : blockchain.img snakelight.img
.PHONY : all-qr
all-qr : blockchain.png snakelight.png
.PHONY : all
all : all-images all-qr
