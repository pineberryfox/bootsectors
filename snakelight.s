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
	mov ax, 0x07c0
	mov ds, ax
	mov es, ax

	mov ax, 0x01
	int 0x10     ; BIOS call - Video Services

	;; disable cursor
	mov ah, 0x01
	mov cx, 0x2000
	int 0x10

game_start:
	;; zero out data
	mov cx, (end_all_data - all_data)
	xor ax, ax
	mov di, all_data
	cld
	rep stosb
	;; set up player
	mov [x], byte 0x14
	mov [y], byte 0x0C
	mov [length], byte 1

	;; set up screen
setup_attributes:
	mov ah, 0x02
	mov [dir], ah
	xor bx, bx
	xor dx, dx
	int 0x10
	mov ax, 0x0920
	mov bl, 0x0D
	mov cx, 25*40
	int 0x10

	xor ax, ax
	mov cx, 13
startup_pattern:
	push ax
	push cx
	call togglei
	pop cx
	pop ax
	add ax, 2
	loop startup_pattern

	int 0x16

loop:
update_player:
	mov cx, 25
	xor bx, bx
	xor al, al
win_check:
	or al, [field + bx]
	inc bx
	loop win_check
	or al, al
	jz game_end

	mov ah, 0x01
	int 0x16 ; is key ready?
	jz end_keys ; if not: no keys
	xor ah, ah
	int 0x16 ; else get it
	cmp ah, 0x24
	jl end_keys
	cmp ah, 0x26
	jg maybe_toggle
	sub ah, 0x25
	add [dir], ah
maybe_toggle:
	cmp ah, 0x39
	jne update_player
	mov [growing], ah
	xor bh, bh
	mov bl, [start]
	xor ah, ah
	mov al, [y + bx]
	mov cl, 0x05
	idiv cl
	mov ah, al
	mov al, [x + bx]
	shr al, 3
	call toggle
	sub ah, 1
	call toggle
	add ah, 2
	call toggle
	sub ah, 1
	sub al, 1
	call toggle
	add al, 2
	call toggle
	jmp update_player
end_keys:
	mov [dead], byte 0xFF
	xor bh, bh
	mov bl, byte [start]
	mov al, [x + bx]
	mov ah, [y + bx]
	mov cl, [dir]
	mov ch, cl
	and ch, 0x02
	sub ch, 0x01
	and cl, 0x01
	jnz vert
horz:
	add al, ch
	jl end_update_player
	cmp al, 40
	jge end_update_player
	sub ah, ch
vert:
	add ah, ch
	jl end_update_player
	cmp ah, 25
	jge end_update_player
end_move:

	;; check for self-collision
	xor ch, ch
	mov cl, [length]
	xor bh, bh
	mov bl, [start]
	jmp coll_loop_end
coll_loop_start:
	cmp [x + bx], al
	jne next_body ; can't be ded
	cmp [y + bx], ah
	je  end_update_player ; ya ded
next_body:
	inc bl
coll_loop_end:
	loop coll_loop_start
	mov [dead], byte 0x00

	dec byte [start]
	mov bl, byte [start]
	mov [x + bx], al
	mov [y + bx], ah
	mov dx, ax
	mov ah, 0x02
	xor bh, bh
	int 0x10 ; put cursor at head
	mov ax, 0x0ADB
	mov cx, 0x0001
	int 0x10

	inc byte [length]
	jz decbl
	test [growing], byte 0xFF
	jnz end_update_player
	mov bl, [start]
	add bl, [length]
	dec bl
	mov dh, [y + bx]
	mov dl, [x + bx]
	mov ah, 0x02
	int 0x10 ; put cursor at old tail
	mov ax, 0x0A20
	int 0x10
decbl:
	dec byte [length]
end_update_player:
	mov [growing], byte 0

	;; wait for the next frame
	xor cx, cx
	mov dx, 0xFA00
	mov ah, 0x86
	int 0x15
	;; if ya ded, no loopin
	test [dead], byte 0xFF
	jz loop

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
	cmp ah, 0
	jl end_toggle
	cmp ah, 5
	jge end_toggle
	cmp al, 0
	jl end_toggle
	cmp al, 5
	jge end_toggle
	xor bh, bh
	mov bl, ah
	shl bl, 2
	add bl, ah
	mov dh, bl
	add bl, al
	xor byte [field + bx], 0xFF
show_cell:
	shl al, 3
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
	inc dl
	loop cell_inner
	sub dl, 8
	pop cx
	inc dh
	loop cell_outer
end_toggle:
	pop ax
	ret


	;; end
times 510 - ($-$$) db 0x90 ; fill up the remainder of the 510-byte segment
dw 0xAA55 ; "BOOTABLE" mark


section .bss
all_data:
x:       resb 256
y:       resb 256
start:   resb 1
length:  resb 1
dir:     resb 1
growing: resb 1
dead:    resb 1
field:   resb 25
end_all_data:
