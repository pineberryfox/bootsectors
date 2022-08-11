;;; SPDX-License-Identifier: MIT

bits 16    ; tell NASM this is 16-bit code
org 0 ; BIOS loads stuff to 0x7C00
	jmp 0x07c0:boot
boot: ; and now we know it is 07c0(*16):0000
	;; set up stack
	cli
	mov ax, 0x0700
	mov ss, ax
	mov sp, ax
	sti
	;; and other segments
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov ax, 0x01
	int 0x10     ; BIOS call - Video Services

	;; disable cursor
	mov ah, 0x01
	mov ch, 0x20
	int 0x10

game_start:
	;; zero out data
	mov cx, (end_all_data - all_data)
	xor ax, ax
	mov di, all_data
	cld
	rep stosb
	;; set up player
	mov [pos], word 0x0C14 ; y=0C, x=14
	mov [length], byte 1

	;; set up screen
setup_attributes:
	mov ah, 0x02
	xor bx, bx
	xor dx, dx
	int 0x10
	mov ax, 0x0920
	mov bl, 0x0D
	mov cx, 25 * 40
	int 0x10

	xor ax, ax
	mov cx, 13
startup_pattern:
	push ax
	push cx
	call togglei
	pop cx
	pop ax
	inc ax
	inc ax
	loop startup_pattern

	int 0x16

loop:
	;; wait for the next frame
	xor ax, ax
	int 0x1A
	mov bl, dl
busy_wait:
	int 0x1A
	cmp dl, bl
	je busy_wait

update_player:
	mov ah, 0x01
	int 0x16 ; is key ready?
	jz short end_keys ; if not: no keys
	xor ah, ah
	int 0x16 ; else get it
	;; rotation: two keys whose difference in scancodes is 2
	;; I like J/L so I can play with only my right hand
	sub ah, 0x24 ; J
	cmp ah, 0x02 ; L (- J)
	ja short maybe_toggle
	dec ah
	add [dir], ah
maybe_toggle:
	cmp ah, 0x39 - 0x24 ; spacebar (- J)
	jne short update_player
	dec byte [growing]
	mov bx, [start]
	shl bx, 1
	xor dx, dx
	mov ax, [pos + bx]
	mov bl, al
	mov cx, 0x0005
	idiv cx
	mov cl, 3
	mov al, bl
	shr al, cl
	call toggle
	;; now for the other four
	dec ah
	call toggle
	add ah, 2
	call toggle
	dec ah
	inc ax
	call toggle
	sub al, 2
	call toggle
	jmp update_player
end_keys:
	xor dx, dx
	mov bx, [start]
	shl bx, 1
	mov ax, [pos + bx]
	mov cl, [dir]
	mov ch, cl
	and ch, 0x02
	dec ch
	and cl, 0x01
	jnz short vert
horz:
	sub al, ch
	cmp al, 40
	jae short game_end ; ya ded
	add ah, ch
vert:
	sub ah, ch
	cmp ah, 25
	jae short game_end ; ya ded
end_move:

	;; check for self-collision
	mov cx, [length]
	mov bx, [start]
	shl bx, 1
	jmp coll_loop_end
coll_loop_start:
	cmp [pos + bx], ax
	je short game_end ; ya ded
next_body:
	inc bx
	inc bx
	and bh, 1
coll_loop_end:
	loop coll_loop_start

	mov bx, start
	dec byte [bx]
	mov bx, [bx]
	shl bx, 1
	mov [pos + bx], ax
	mov dx, ax
	mov ah, 0x02
	xor bh, bh
	int 0x10 ; put cursor at head
	mov ax, 0x0ADB
	mov cx, 0x0001
	int 0x10

	inc byte [length]
	jz short decbl
	inc byte [growing]
	jz short end_update_player
	mov bx, [start]
	add bl, [length]
	dec bl
	shl bx, 1
	mov dx, [pos + bx]
	xor bh, bh
	mov ah, 0x02
	int 0x10 ; put cursor at old tail
	mov ax, 0x0A20
	int 0x10
decbl:
	dec byte [length]
end_update_player:
	mov cx, 25
	mov bx, field - 1
	xor ax, ax
	mov [growing], al
win_check:
	inc bx
	or al, [bx]
	loop win_check
	jz short game_end

	jmp loop

game_end:
	xor ah, ah
	int 0x16
	jmp game_start


	;; index: ax
togglei:
	mov cl, 5
	div cl
	xchg al, ah

	;; row: ah
	;; col: al
toggle:
	push ax
	cmp ah, 4
	ja short end_toggle
	cmp al, 4
	ja short end_toggle
	xor bh, bh
	mov bl, ah
	shl bl, 1
	shl bl, 1
	add bl, ah
	mov dh, bl
	add bl, al
	not byte [field + bx]
show_cell:
	mov cl, 3
	shl al, cl
	mov cx, 0x05
	mov dl, al
cell_outer:
	push cx
	mov cx, 0x08
cell_inner:
	mov ax, 0x0200
	xor bh, bh
	int 0x10
	mov ax, 0x0800
	int 0x10
	xor ah, 0x30
	mov bl, ah
	mov ah, 0x09
	push cx
	mov cx, 0x01
	int 0x10
	pop cx
	inc dx
	loop cell_inner
	sub dl, 8
	pop cx
	inc dh
	loop cell_outer
end_toggle:
	pop ax
	ret


	;; end
times 440 - ($-$$) db 0x90 ; fill up the remainder of the 440-byte code
db "PINE"
dq 0x0000
times 510 - ($-$$) db 0x00 ; no partitions
dw 0xAA55 ; "BOOTABLE" mark


section .bss
all_data:
pos:     resw 256
start:   resw 1
length:  resw 1
dir:     resb 1
growing: resb 1
field:   resb 25
end_all_data:
