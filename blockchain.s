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
	;; wait for the next frame
;; 	xor ax, ax
;; 	int 0x1A
;; 	mov bl, dl
;; .busy_wait:
;; 	int 0x1A
;; 	cmp dl, bl
;; 	je short .busy_wait
	hlt

.in:
	mov ah, 0x02
	xor bx, bx
	mov dx, [pos]
	add dx, 0x0a11
	int 0x10
	mov cx, 0x0607
	mov ah, 0x01
	int 0x10

	mov ah, 1
	int 0x16
	jnz short .end_move ; no characters
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
	mov cx, 8
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
	jmp handle_clears
	;; tail-call / tail-recursion

show_field:
	mov ch, 0x20 ; no cursor!
	mov ah, 0x01
	int 0x10

	xor si, si ; field
	mov di, 8
	mov dx, 0x0910
.show_base_field:
	mov cx, 8
.show_base_row:
	push dx
	push cx
	mov ah, 0x02
	xor bx, bx
	int 0x10 ; cursor position
	xor ax, ax
	lodsb
	mov bx, ax
	mov ah, 0x09
	mov cl, 0x01
	int 0x10 ; character and attributes
	pop cx
	pop dx
	inc dx
	loop .show_base_row
	add dx, 0x00F8
	dec di
	jnz .show_base_field
	ret

zero_fill:
	push cx
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
	mov ax, [score]
	mov word [temp], 0x1217
.loop:
	push ax
	mov ah, 2
	xor bx, bx
	mov dx, [temp]
	int 0x10
	pop ax
	mov cx, 10
	xor dx, dx
	div cx
	push ax
	mov al, dl
	add al, 0x30
	mov ah, 0x0a
	xor bx, bx
	mov cx, 1
	int 0x10
	pop ax
	dec word [temp]
	or ax, ax
	jnz short .loop
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
temp:      resw 1
did_clear: resb 1
rnd:       resw 1
