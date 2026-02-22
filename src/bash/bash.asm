org 0x7c00
bits 16

; start code for confirmation
start:
	mov ah, 0x0E   ; Teletype mode
	mov al, '>'    ; Een prompt teken
	int 0x10       ; Print het

;main loop.
main:
	; Get key.
	; Output in AL.
	mov ah, 0x00
	int 0x16

	; Check if the user typed a backspace. for the wrap we need to check it now.
	cmp al,8
	je main_backspace

	; Print key.
	; Input in AL which lines uo with the Get Key output.
	mov ah, 0x0e
	int 0x10



	; Jump back for the loop.
	jmp main

;handles the backspace.
main_backspace:
	; segment location of the BDA colomn and row.
	; push and pop is needed cause mov es, 0x0040 gives a error.
	; after that we move colomn in DL and row in DH.
	push 0x0040      
	pop es
	mov dx, [es:0x50]
		
	; now we need to see if the colomn (DL) it is zero.
	; we test against itself cause that also sets the zero flag if it is zero.
	; if it is zero we jump to the wrap handler.
	; from the wrap handler we also jump back to the main loop.
	test dl, dl
	jz main_backspace_wrap

	; print the backspace
	int 0x10
	
	; ah is still the same i geuss.
	; start of by setting al to 0, for smaller size ill use the xor operation.
	; there also isn't a danger cause im not resetting any used flags
	xor al, al
	
	;now print it.
	int 0x10

	;now that it is printed we need to add a backspace. doable by either moving or adding.
	; im gonna be moving cause it is the same size as add and it is more clear.
	mov al, 8

	;now print the backspace.
	int 0x10

	
	;and now go back to the main loop.
	jmp main

; handles the wrap for the backspace.
main_backspace_wrap:
	; BIOS call set cursor
	mov ah, 02h
	; xor is smaller and is okay right now
	xor bh, bh
	; decrement the row to go up. we already have the value
	dec dh
	; dl needs to be the max value (79)
	mov dl, 79
	; call the BIOS
	int 0x10
	
; the magic code.
times 510-($-$$) db 0
dw 0xaa55
