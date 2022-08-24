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
	mov [score], dx ; zeroed in handle_clears

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

	mov bx, pos + 1
	cmp ah, 0x11
	jne short .not_w
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
	dec byte [time] ; decrease remaining rotations
	js short boot ; lost :c ... restart! by resetting everything!
	call rotate
	jmp .end_move
.no_rot:
	sub ah, 0x0E
	cmp ah, 2
	ja short .not_asd
	;; mov bx, pos + 1 ; still set from above
	dec ah
	jnz short .horz
	cmp byte [bx], 5
	je short .horz
	inc byte [bx]
.horz:
	dec bx
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
	call zero_fill ; al is zero'd here for stosb
	;; so this pass-through works fine!
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
	mov si, field + (6 * 8) + 7
	mov di, field + (7 * 8) + 7
	xor bp, bp
	xor cx, cx
.gravity_cell:
	cmp [di], ch
	jnz short .end_cell
	mov ah, [si]
	mov [di], ah
	mov [si], ch
.end_cell:
	dec di
	dec si
	jns short .gravity_cell
.fill:
	cmp byte [di], ch ; ch remains zero (as does cl)
	jnz short .nonempty
	call rand
	mov ah, 3
	and al, ah
	add al, ah
	mov [di], al
	inc bp ; never more than 8
.nonempty:
	dec di
	jns short .fill ; relies on field being 0
	neg bp
	js short gravity

	neg byte [did_clear]
	js short handle_clears ; cx is still 0 from the above LOOP
	;; tail-recursion
	;; call show_field by fall-through

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

	;; xorshift:
	;; x ^= x << 3
	;; x ^= x >> 1
	;; x ^= x << 12
	;; this one has a complete period,
	;; and lets us avoid a cl store
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
	times 440 - ($ - $$) db 0x90 ;NOP the rest of the code section
	db "VXN~" ; identifier
	dw 0x0000
	times 510 - ($-$$) db 0x00 ; no partitions
	dw 0xAA55 ; "BOOTABLE" mark


section .bss
ABSOLUTE 0 ; Base of initial RAM
field:     resb 64
pos:       resw 1
score:     resw 1
time:      resb 1
did_clear: resb 1
rnd:       resw 1
