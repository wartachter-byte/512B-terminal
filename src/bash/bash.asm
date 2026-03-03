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
	mov [boot_drive], dl

	; clears the screen by resetting the videomode. causes flicker, but its smaller
	; ah=00h videomode set al=03h, standard videomode
	mov ax, 0003h
	int 0x10

	; load the 2 sectors following us. ax = 1, cl = 2, es:bx = 0x0000:0x7e40
	mov ax, 1
	mov cl, 2
	mov bx, 0x7e40
	call load
	
	; the buffer is after our code so on 0x07d00
	; segment = 0x07dxx >>> 0x07d0
	; offset = 0, just do xor di, di
	push 0x07d0
	pop es
	xor di, di

common_start:
	; prints '> '
		
	mov ah, 0x0E
	mov al, '>'
	int 0x10
	mov al, ' '
	int 0x10	

;main loop.
main:
	; Get key.
	; Output in AL.
	mov ah, 0x00
	int 0x16

	
	; Check if the user typed a backspace
	cmp al,8
	je main_backspace

	; Check if the user pressed enter
	; Also i litteraly forgot i already implented this for a moment
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
	; The run command is gonna follow a trie loaded at the start.
	; The trie operates like this:
	; Byte 1: the character to check with
	; Byte 2-3: The pointer to where
	; if Byte 1 is a null it means that this defines the end of this layer.
	; So if we can't find one, we simply go back to the common_start and move all again
	; Now if we find one that points to a null and the current value is a space, then we must load the
	; pointer of that thing, because that pointer has the location.

	; Plan: Move back the buffer thing, loop: [load, check and keep track of correct]

	; move the buffer back to the front which is just setting the offset to zero as the offset
	; is mainly used
	; Also the offset is SI for lodsb and the segment DS
	; now we need (DI >> SI and ES >> DS)
	mov si, di
	mov ds, es
	; we can now use some other registers that we will need.
	; we will now use ES:DI as our trie pointer
	; ES >> 0x07e4	DI >> 0x0000
	; set ES
	push 0x07e4
	pop es
	; Clear DI
	xor di, di

	; Now that the setup is complete we can start.
	; we will need to do losb and then compare against the [ES:DI]
	; If it is not correct we dill inc di (if [ES:DI] is zero then we will go to run_z) and try again
	; Exception: If AL is 0x20 and [ES:DI] is zero, then we found the last pointer.

run_loop:
	; load the first byte into AL
	lodsb
	
run_subloop:
	; Now compare it.
	cmp al, [es:di]
	; not eqaul? try again
	jne run_retry
	; is eqaul? go to the next item
; useless label
run_next:
	; for the next item, we must get the pntr. it will be loaded in little-endian
	; so the trie stores it in little-endian to countercat this.
	; now it will be based of 0x0000 and so we can use ES:BX
	; But to laod it quick, i can use DI to store it in, instanlty loading it
	mov di, [es:di]
	; we just loaded so we can just jump back
	jmp run_loop

run_retry:
	; add DI 3 for the next item
	add di, 3
	; Is it zero?
	test di, di
	; if so > run_z
	jz run_z
	; If not: go back to try again
	jmp run_subloop

run_z:
	; is AL space (0x20)?
	cmp al, 0x20
	; if it is space: jmp to run_load
	je run_load
	; if not: we failed
	jmp run_fail

run_load:
	; loads it

run_fail:
	; if it fails.
	
; Loads a sector using LBA
; in:
; 	ax - Sector
;	cl - Count of sectors
; 	es:bx - Where to put
; out:
; 	Putted on memory
; modifications:
; 	None
load:
	; i want to store the regs passed in so that we dont have any problem
	; Start
	pusha
	push es

	; Now i want to calculate the CHS.
	; I dont want to recalculate everytime, so im just gonna store it.
	; Also save some important regs that will be modified
	push cx
	push bx
	; Now call the conversion
	call load_convert
	; Now restore the values into their respective locations (BX, AX (because BIOS))
	pop bx
	pop ax

	; now for some final thingy's:
	; BIOS call
	mov ah, 02h
	; 3 times
	mov si, 3

	; and then store it
	pusha
	; Also push ES beacuse it is not included in pusha but still vital
	push es

	; now we are ready
load_loop:
	; clear the carry flag for the BIOS
	clc
	; now call the BIOS
	int 13h
	; did smth went wrong?
	jc load_fail
 	; no?:

	jmp load_complete

load_fail:
	; reset the drive controller
	; ah = 00h
	xor ah, ah
	; int 13h
	int 13h

	; Get the stored setup
	pop es
	popa


	; Now decrement SI for the 3 times
	dec si
	; now store the setup again
	pusha
	push es
	
	; Is it not yet zero??
	test si, si
	; if so: go back to the loop with the correct things.
	jnz load_loop

	; here it is zero:
load_complete:
	; Remove the last setup and restore the regs to before the call
	pop es
	popa
	
	; End
	pop es
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
load_convert:
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
	mov bl, [boot_drive]

	; Now we can do the mov operations.
	; Move the Head to DH; Loads a sector using LBA
	
	mov dh, dl
	; Move the drive-number to dl
	mov dl, bl
	; Move the Cylinder to CH
	mov ch, al

	; return!!!!!!!!
	ret
	
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

boot_drive: db 0

; the magic code.
times 510-($-$$) db 0
dw 0xaa55
