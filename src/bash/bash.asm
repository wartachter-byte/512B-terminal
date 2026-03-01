org 0x7c00
bits 16

%define SectorsPerTrack 18
%define NumberOfHeads 2

; start code for confirmation
start:
	; Set the stack pointer to the start of our code beacuse it grows downward
	mov sp, 0x7c00

	; also this is at the start cause dl wil contain the boot drive ID
	; and idk what all these BIOS calls after this do to dl
	; and we modify di later on to
	push dx

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

	cmp al, 13
	je run

	; check offset of buffer against 63
	cmp di, 63
	; if bigger or eqaul. so beyond buffer or at the end of it, go back to the main and dont print anything
	jae main

	; store the currently typed byte
	stosb

main_resume:
	; Print key.
	; Input in AL which lines uo with the Get Key output.
	mov ah, 0x0e
	int 0x10

	

	; Jump back for the loop.
	jmp main

run:
	; pass

; Loads a sector using LBA
; in:
; 	ax - Sector
;	cl - Count of sectors
; 	es:bx - Where to put
; out:
; 	Putted on memory
.load:
	; Using the LBA_to_CHS function, i need to preserve some registers.
	; Mainly: cx and bx
	; As these registers are modified
	; Also we want to modify no primary registers.
	pusha

	; So now need to calculate.
	; The BIOS could fail and i don't want to uselessly recalculate.
	; So we are gonna calculate and then store the result.
	; except, the calculation modifies a lot.
	; So il just set it up once and then store it.

	push cx
	push bx
	push es
	call .load_convert
	pop es
	pop bx
	pop ax
	mov ah, 02h
	pusha
	push es
	mov si, 3
	
.load_loop:
	int 13h
	jnc .load_succes

	pop es
	popa

	xor ax, ax
	int 13h

	dec si
	jnz .load_loop

	jmp .load_fail

.load_succes:
	popa
	ret

.load_fail:
	popa
	ret
	
; converts LBA to CHS
; in:
; 	ax - LBA
; out:
; 	ch - low 8 bits of cylinder
; 	cl =
;		0-5 - sector
;		6-7 - upper 2 bits of cylinder
;	dh - head
; 	dl - drive number
; modifications:
; 	ax, bx, cx, dx
.load_convert:
	; Sector   = (LBA % SPT) + 1
	; Head 	   = (LBA / SPT) % NOH
	; Cylinder = (LBA / SPT) / NOH

	; Plan:
	; Calculate (LBA /% SPT), and +1, and /%NOH. lastly move some regs.
	
	
	; clean dx because div uses DX:AX
	xor dx, dx
	; set the value in bx for the div
	mov bx, SectorsPerTrack
	; divide!
	div bx

	; Calculate the rest of the remainder/Sector.
	inc dx
	; store the remainder/Sector for later.
	push dx

	; Now for the head and cylinder
	; clean dx because div uses DX:AX
	xor dx, dx
	; set the value in bx for the div
	mov bx, NumberOfHeads
	; DIVIDE!!!
	div bx

	; Now DL has the Head, AL the Cylinder, and the Sector is in the stack.
	; The Head must be in DH, the Cylinder in CH, and the Sector in CL
	; Pop's must be done first, because they operate 16-bit
	
	; Get the sector. It is in CL now, which is perfect.
	pop cx
	; Get the drive number. It now is in BL. Im storing it in BX because the head is in DX
	pop bx
	; Also save it again.
	push bx

	; Now we can do the mov operations.
	; Move the Head to DH
	mov dh, dl
	; Move the drive-number to dl
	mov dl, bl
	; Move the Cylinder to CH
	mov ch, al
	
; just handels the buffers
; modify's di, ah and al
; di - buffer offset
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
	jmp main_resume


; the magic code.
times 510-($-$$) db 0
dw 0xaa55
