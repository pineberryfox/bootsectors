;;; SPDX-License-Identifier: MIT

TO_MATCH equ 5

bits 16
org 0x7C00
	;jmp 0x0000:boot
boot:	; work around old Compaq BIOS having weird segments
	;; set up stack
	cli
	mov ax, 0x0700
	mov ss, ax
	mov sp, ax ; stack is at $7700
	sti
	;; and configure other segments: map ds:0 to 0x0500
	mov ax, 0x0050
	mov ds, ax
	mov es, ax

	;; set up display
	mov al, 0x01
	or [rnd], al ; guarantee non-zero
	int 0x10


	;; init_field
	cld
	xor di, di ; field
	mov cx, 32
	mov ax, 0x0303
	mov [pos], ax ; convenient initialization
	rep stosw
	call handle_clears
	xor ax, ax
	mov [score], ax

main_loop:
.in:
	mov ah, 0x02
	xor bx, bx
	mov dx, [pos]
	add dx, 0x0a11
	int 0x10

	;; blocking wait for keypress
	xor ax, ax
	int 0x16

	cmp ah, 0x11
	jne short .not_w
	mov bx, pos + 1
	dec byte [bx]
	jns short .in
	inc byte [bx]
	jmp .in
.not_w:
	mov bp, ccw_indices
	sub ah, 0x10
	jz short .cclock
	cmp ah, 2
	ja short .no_rot
	mov bp, cw_indices
.cclock:
	call rotate
	jmp .end_move
.no_rot:
	sub ah, 0x0E
	cmp ah, 2
	ja short .not_asd
	mov bx, pos
	dec ah
	jnz short .horz
	cmp byte [bx + 1], 5
	je short .horz
	inc byte [bx + 1]
.horz:
	add ah, [bx]
	cmp ah, 5
	ja short .in
	mov [bx], ah
.not_asd:
.end_move:
setup:
	call show_score
	jmp main_loop

rotate:
	dec byte [time] ; decrease remaining rotations
	jns short .in
	jmp boot ; lost :c ... restart! by resetting everything!
.in:
	xor ax, ax
	mov bx, [pos]
	mov cl, 3
	shl bh, cl
	add bl, bh
	xor bh, bh
	mov dl, [bx]
	mov cx, 7
.loop:
	mov si, cx
	mov di, cx
	dec si
	mov al, [cs:bp+si]
	mov si, ax
	mov al, [cs:bp+di]
	mov di, ax
	mov dh, [bx+si]
	mov [bx+di], dh
	loop .loop
	mov [bx+si], dl
	;jmp handle_clears
	;; tail-call
	;; by lack-of anything

handle_clears:
	mov byte [did_clear], 0

check_clears: ; inlined
	xor bx, bx ; field
	mov cl, 8 ; it's zero'd from above
.check_row:
	mov ah, 0xff
	xor dx, dx
	push cx
	mov cx, 8
.check_cell:
	mov al, cl
	dec ax
	xlat
	inc dx
	cmp al, ah
	je short .same_as_prev
	cmp dl, TO_MATCH
	jb short .small_chain
	call zero_fill
.small_chain:
	mov ah, al
	xor dx, dx
.same_as_prev:
	loop .check_cell
	inc dx
	cmp dl, TO_MATCH
	jb short .end_check_row
	call zero_fill
.end_check_row:
	pop cx
	add bx, 8
	loop .check_row

gravity: ; inlined
	mov bp, temp
	mov bx, field + (6 * 8)
	mov cx, 7
	mov [bp], ch
.gravity_rows:
	push cx
	mov cx, 8
.gravity_row:
	mov ax, cx
	dec ax
	mov si, ax
	add ax, 8
	mov di, ax
	xlat
	or al, al
	jnz short .end_row
	mov ah, [bx+si]
	mov [bx+di], ah
	mov [bx+si], al
.end_row:
	loop .gravity_row
	pop cx
	sub bx, 8
	loop .gravity_rows
	mov bx, field + 7
	mov cx, 8
.fill:
	test byte [bx], 0xff
	jnz short .nonempty
	push bx
	call rand
	pop bx
	mov ah, 3
	and al, ah
	add al, ah
	mov [bx], al
	inc byte [bp] ; never more than 8
.nonempty:
	dec bx
	loop .fill
	neg byte [bp]
	js short gravity

	neg byte [did_clear]
	jns short show_field
	jmp handle_clears ; cx is still 0 from the above LOOP
	;; tail-call / tail-recursion

show_field:
	push es
	mov ax, 0xB800
	mov es, ax
	mov di, 0x02f0
	xor si, si ; field
	mov dx, 8
.row:
	mov cx, 8
.cell:
	movsb
	dec si
	movsb
	loop .cell
	add di, 80 - 16
	dec dx
	jnz .row
	pop es
	ret

zero_fill:
	push cx
	mov byte [time], 5
	add [score], dx
	mov [did_clear], dl
	add cx, bx
	mov di, cx
	mov cx, dx
	xor al, al
	rep stosb
	pop cx
	ret

rand:
	push cx
	mov bx, rnd
	mov ax, [bx]
	mov dx, ax
	mov cl, 3
	shl dx, cl
	xor ax, dx
	mov dx, ax
	shr dx, 1
	xor ax, dx
	mov dx, ax
	mov cl, 12
	shl dx, cl
	xor ax, dx
	mov [bx], ax
	pop cx
	ret

show_score:
	push es
	mov ax, 0xB800
	mov es, ax
	mov di, 0x05D2
	std
	mov al, [time]
	or al, 0x30
	stosb
	xor ax, ax
	dec di
	stosw
	mov ax, [score]
	mov cx, 10
.loop:
	xor dx, dx
	div cx
	add dx, 0x0730
	push ax
	mov ax, dx
	stosw
	pop ax
	or ax, ax
	jnz short .loop
	cld
	pop es
	ret

ccw_indices:
	db 8, 16, 17, 18, 10, 2, 1, 0
cw_indices:
	db 1, 2, 10, 18, 17, 16, 8, 0

	;; end
	;times 440 - ($ - $$) db 0x90 ;NOP the rest of the code section
	;db "VXN~" ; identifier
	;dq 0x0000
	;times 510 - ($-$$) db 0x00 ; no partitions
	times 510 - ($-$$) db 0x90 ; no partitions
	dw 0xAA55 ; "BOOTABLE" mark


section .bss
ABSOLUTE 0 ; Base of initial RAM
field:     resb 64
pos:       resw 1
score:     resw 1
time:      resb 1
temp:      resb 1
did_clear: resb 1
rnd:       resw 1
