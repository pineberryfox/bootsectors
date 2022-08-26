;;; SPDX-License-Identifier: MIT

TO_MATCH equ 5

bits 16
cpu 8086
org 0x7C00
	jmp 0x0000:boot
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
	mov dx, [bx + pos]
	add dx, 0x0a11
	int 0x10

	;; blocking wait for keypress
	xor ax, ax
	int 0x16
	mov al, ah

	mov bx, pos + 1
	cmp al, 0x11
	jne short .not_w
	dec byte [bx]
	jns short .in
	inc byte [bx]
	jmp .in
.not_w:
	mov bp, ccw_indices
	sub al, 0x10
	jz short .cclock
	cmp al, 2
	ja short .no_rot
	add bp, 8
.cclock:
	dec byte [bx + time - (pos + 1)] ; decrease rotations
	js short boot ; lost :c ... restart! by resetting everything!
	call rotate
	jmp .end_move
.no_rot:
	sub al, 0x0E
	cmp al, 2
	ja short .not_asd
	;; mov bx, pos + 1 ; still set from above
	dec al
	jnz short .horz
	cmp byte [bx], 5
	je short .horz
	inc byte [bx]
.horz:
	dec bx
	add al, [bx]
	cmp al, 5
	ja short .in
	mov [bx], al
.not_asd:
.end_move:
	call show_score
	jmp main_loop

rotate:
	mov ax, [pos]
	mov cl, 32
	div cl
	add al, ah
	cbw
	xchg ax, bx ; bh was 0, so ah is 0 now
	mov dl, [bx]
	mov cx, 7
.loop:
	mov si, cx
	mov di, cx
	dec si
	mov al, [cs:bp+si]
	xchg ax, si
	mov al, [cs:bp+di]
	xchg ax, di
	mov dh, [bx+si]
	mov [bx+di], dh
	loop .loop
	mov [bx+si], dl
	;jmp handle_clears
	;; tail-call
	;; by lack-of anything

handle_clears:
	xor bx, bx
	mov byte [bx + did_clear], cl ; zero'd by above loop

check_clears: ; inlined
	xor di, di
.check_row:
	mov cl, 8
.check_cell:
	mov dx, cx
	mov al, [di]
	repz scasb
	jz .nodec ; ran out of string
	dec di ; else we're one past the first different thing
	inc cx
.nodec:
	sub dx, cx
	cmp dl, TO_MATCH
	jb short .small_chain
	push cx
	mov byte [bx + time], 5
	add [bx + score], dx
	mov [bx + did_clear], dl
	sub di, dx
	xor al, al
	mov cx, dx
	rep stosb
	pop cx
	;; so this pass-through works fine!
.small_chain:
	inc cx
	loop .check_cell
.end_check_row:
	cmp di, 64
	jc .check_row

gravity: ; inlined
	mov si, field + (6 * 8) + 7
	mov di, field + (7 * 8) + 7
	xor bp, bp
.gravity_cell:
	cmp [di], ch
	jnz short .end_cell
	movsb
	dec si
	dec di
	mov [si], ch
.end_cell:
	dec di
	dec si
	jns short .gravity_cell
.fill:
	cmp byte [di], ch ; ch remains zero (as does cl)
	jnz short .nonempty

	;; xorshift:
	;; x ^= x << 3
	;; x ^= x >> 1
	;; x ^= x << 12
	;; this one has a complete period,
	;; and lets us avoid a cl store
.rand: ; inlined
	push cx
	mov bl, rnd ; bh is zero whenever this is called
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

	and al, 3
	add al, 3
	mov [di], al
	inc bp ; never more than 8
.nonempty:
	dec di
	jns short .fill ; relies on field being 0
	neg bp
	js short gravity

	neg byte [di + did_clear + 1] ; di==-1 was the exit condition
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

show_score:
	push es
	mov ax, 0xB800
	mov es, ax
	mov di, 0x05D2 ; position appropriately in memory
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
	xchg ax, dx
	stosw
	xchg ax, dx
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
