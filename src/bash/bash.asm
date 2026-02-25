org 0x7c00
bits 16

; start code for confirmation
start:
	; clears the screen by resetting the videomode. causes flicker, but its smaller
	; ah=00h videomode set al=03h, standard videomode
	mov ax, 0003h
	int 0x10
	
	; prints '> ' for confirmation
	
	mov ah, 0x0E
	mov al, '>'
	int 0x10
	mov al, ' '
	int 0x10
	
	; the buffer is after our code so on 0x07d00
	; segment = 0x07dxx >>> 0x07d0
	; offset = 0, just do xor di, di
	push 0x07d0
	pop es
	xor di, di

;main loop.
main:
	; Get key.
	; Output in AL.
	mov ah, 0x00
	int 0x16

	
	; Check if the user typed a backspace
	cmp al,8
	je main_backspace

	
main_resume_a:
	; check offset of buffer against 63
	cmp di, 63
	; if bigger or eqaul. so beyond buffer or at the end of it, go back to the main and dont print anything
	jae main

	; store the currently typed byte
	stosb

main_resume_b:
	; Print key.
	; Input in AL which lines uo with the Get Key output.
	mov ah, 0x0e
	int 0x10

	

	; Jump back for the loop.
	jmp main

;handles the backspace.
main_backspace:

	; is the buffer empty?
	; if so: just go back
	test di, di
	jz main
	

	; move the buffer pointer back 1
	dec di
	; for print
	mov ah, 0x0e
	; print the backspace
	int 0x10
	
	; ah is still the same.
	; move a space to al
	mov al, ' '
	
	;now print it.
	int 0x10

	; now that it is printed we need to add a backspace
	mov al, 8

	
	;and now go back to the main loop.
	jmp main_resume_b

	
; the magic code.
times 510-($-$$) db 0
dw 0xaa55
