;;; SPDX-License-Identifier: MIT

TO_MATCH equ 3

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

	cld
	mov di, field
	mov cx, 32
init_field:
	push cx
	call rand
	pop cx
	mov bx, 0x0303
	mov [pos], bx ; convenient intialization
	and ax, bx
	add ax, bx
	stosw
	loop init_field
	call handle_clears
	;xor ax, ax
	;mov [score], ax
	;jmp setup

main_loop:
	call wait_frame
	;mov byte [rotated], 0
	mov ah, 1
	int 0x16
	jnz short main_loop ; no characters
	xor ax, ax
	int 0x16

	cmp ah, 0x11
	jne short .not_w
	mov bx, pos + 1
	dec byte [bx]
	jnz .end_move
	inc byte [bx]
	jmp .end_move
.not_w:
	cmp ah, 0x39
	jne short .not_space
	call rotate_ccw
	jmp .end_move
.not_space:
	sub ah, 0x1E
	cmp ah, 2
	ja short .not_asd
	mov bx, pos
	dec ah
	jnz .horz
	cmp byte [bx + 1], 6
	je .horz
	inc byte [bx + 1]
.horz:
	add ah, [bx]
	jz .end_move
	cmp ah, 6
	ja .end_move
	mov [bx], ah
.not_asd:
.end_move:
	;test byte [rotated], 0xff
	;jz short show_curs
	call handle_clears
setup:
	call show_score
show_curs:
	mov ah, 0x02
	xor bx, bx
	mov dx, [pos]
	add dx, 0x0910
	int 0x10
	mov cx, 0x0607
	mov ah, 0x01
	int 0x10
	jmp main_loop

rotate_ccw:
	mov bx, [pos]
	sub bx, 0x0101
	mov cl, 3
	shl bh, cl
	add bl, bh
	xor bh, bh
	mov al, [bx]
	mov dl, [bx + 1]
	mov [bx], dl
	mov dl, [bx + 2]
	mov [bx + 1], dl
	mov dl, [bx + 10]
	mov [bx + 2], dl
	mov dl, [bx + 18]
	mov [bx + 10], dl
	mov dl, [bx + 17]
	mov [bx + 18], dl
	mov dl, [bx + 16]
	mov [bx + 17], dl
	mov dl, [bx + 8]
	mov [bx + 16], dl
	mov [bx + 8], al
	ret

handle_clears:
	mov byte [did_clear], 0
	call check_clears
	call gravity
	call show_field
	call wait_frame
	test byte [did_clear], 0xff
	jnz short handle_clears
	ret

check_clears:
	mov bx, field
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
	push ax
	call zero_fill
	pop ax
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
	ret

zero_fill:
	push cx
	;add [score], dx
	mov [did_clear], dl
	add cx, bx
	mov di, cx
	mov cx, dx
	xor ax, ax
	rep stosb
	pop cx
	ret

gravity:
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
	push cx
	push bx
	call rand
	pop bx
	pop cx
	mov ah, 3
	and al, ah
	add al, ah
	mov [bx], al
	inc byte [bp] ; never more than 8
.nonempty:
	dec bx
	loop .fill
	test byte [bp], 0xff
	jnz short gravity
	ret

show_field:
	mov ch, 0x20 ; no cursor!
	mov ah, 0x01
	int 0x10

	mov si, field
	mov cx, 8
	mov dx, 0x0910
.show_base_field:
	push cx
	mov cx, 8
	push dx
.show_base_row:
	push dx
	mov ah, 0x02
	xor bx, bx
	int 0x10 ; cursor position
	xor ax, ax
	lodsb
	mov bx, ax
	mov ah, 0x09
	push cx
	mov cl, 0x01
	int 0x10 ; character and attributes
	pop cx
	pop dx
	inc dx
	loop .show_base_row
	pop dx
	pop cx
	inc dh
	loop .show_base_field
	ret

wait_frame:
	;; wait for the next frame
	xor ax, ax
	int 0x1A
	mov bl, dl
.busy_wait:
	int 0x1A
	cmp dl, bl
	je short .busy_wait
	ret

rand:
	mov bx, rnd
	mov ax, [bx + 2]
	mov cl, 5
	mov dx, ax
	shl ax, cl
	xor dx, ax
	mov ax, [bx]
	mov [bx + 2], ax
	mov cx, ax
	shr ax, 1
	xor ax, cx
	mov cl, 3
	xor ax, dx
	shr dx, cl
	xor ax, dx
	mov [bx], ax
	ret

show_score:
;; 	mov ax, [score]
;; 	mov word [temp], 0x1217
;; .loop:
;; 	push ax
;; 	mov ah, 2
;; 	xor bx, bx
;; 	mov dx, [temp]
;; 	int 0x10
;; 	pop ax
;; 	mov cx, 10
;; 	xor dx, dx
;; 	div cx
;; 	push ax
;; 	mov al, dl
;; 	add al, 0x30
;; 	mov ah, 0x0a
;; 	xor bx, bx
;; 	mov cx, 1
;; 	int 0x10
;; 	pop ax
;; 	dec word [temp]
;; 	or ax, ax
;; 	jnz short .loop
	ret

	;; end
	;times 440 - ($ - $$) db 0x90 ;NOP the rest of the code section
	;db "VXN~" ; identifier
	;dq 0x0000
	;times 510 - ($-$$) db 0x00 ; no partitions
	times 510 - ($-$$) db 0x00 ; no partitions
	dw 0xAA55 ; "BOOTABLE" mark


section .bss
ABSOLUTE 0 ; Base of initial RAM
field:     resb 64
pos:       resw 1
score:     resw 1
temp:      resw 1
did_clear: resb 1
rotated:   resb 1
init_end: ; leave rand uninitialized
rnd:       resw 2
