org 0x7c00
bits 16

main:

	; Get key
	; Output in AL
	mov ah, 0x00
	int 0x16

	; Print key
	; Input in AL which lines uo with the Get Key output
	mov ah, 0x0e
	int 0x10

	; Jump back for the loop
	jmp main
	
; the magic code
times 510-($-$$) db 0
dw 0xaa55
