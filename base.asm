IDEAL
MODEL small
STACK 100h
DATASEG
	startPage db 'open.bmp',0
	frame db 'frame.bmp',0
	filehandle dw ?
	Header db 54 dup (0)
	Palette db 256*4 dup (0)
	ScrLine db 320 dup (0)
	ErrorMsg db 'Error', 13, 10 ,'$'
	x dw 160
	y dw 100
	green equ 2
	black equ 0
	Clock equ es:6Ch
	StartMessage db 'Counting 10 seconds. Start...',13,10,'$'
	EndMessage db '...Stop.',13,10,'$'
CODESEG
proc OpenFile
	; Open file
	push bp
	mov bp,sp
	mov ah, 3Dh
	xor al, al
	mov dx, [bp+4]
	int 21h
	jc openerror
	mov [filehandle], ax
	pop bp
	ret 2
openerror :
	mov dx, offset ErrorMsg
	mov ah, 9h
	int 21h
	pop bp 
	ret 2
endp OpenFile
proc ReadHeader
	; Read BMP file header, 54 bsytes
	mov ah,3fh
	mov bx, [filehandle]
	mov cx,54
	mov dx,offset Header
	int 21h
	ret
endp ReadHeader
proc ReadPalette
	; Read BMP file color palette, 256 colors * 4 bytes (400h)
	mov ah,3fh
	mov cx,400h
	mov dx,offset Palette
	int 21h
	ret
endp ReadPalette
proc CopyPal
	; Copy the colors palette to the video memory
	; The number of the first color should be sent to port 3C8h
	; The palette is sent to port 3C9h
	mov si,offset Palette
	mov cx,256
	mov dx,3C8h
	mov al,0
	; Copy starting color to port 3C8h
	out dx,al
	; Copy palette itself to port 3C9h
	inc dx
PalLoop:
	; Note: Colors in a BMP file are saved as BGR values rather than RGB .
	mov al,[si+2] ; Get red value .
	shr al,2 ; Max. is 255, but video palette maximal
	; value is 63. Therefore dividing by 4.
	out dx,al ; Send it .
	mov al,[si+1] ; Get green value .
	shr al,2
	out dx,al ; Send it .
	mov al,[si] ; Get blue value .
	shr al,2
	out dx,al ; Send it .
	add si,4 ; Point to next color .
	; (There is a null chr. after every color.)
	loop PalLoop
	ret
endp CopyPal
proc CopyBitmap
	; BMP graphics are saved upside-down .
	; Read the graphic line by line (200 lines in VGA format),
	; displaying the lines from bottom to top.
	mov ax, 0A000h
	mov es, ax
	mov cx,200
PrintBMPLoop:
	push cx
	; di = cx*320, point to the correct screen line
	mov di,cx
	shl cx,6
	shl di,8
	add di,cx
	; Read one line
	mov ah,3fh
	mov cx,320
	mov dx,offset ScrLine
	int 21h
	; Copy one line into video memory
	cld ; Clear direction flag, for movsb
	mov cx,320
	mov si,offset ScrLine
	rep movsb ; Copy line to the screen
	 ;rep movsb is same as the following code :
	 ;mov es:di, ds:si
	 ;inc si
	 ;inc di
	 ;dec cx
	;loop until cx=0
	pop cx
	loop PrintBMPLoop
	ret
endp CopyBitmap
proc createStartingPage
	; Process BMP file
	push offset startPage
	call OpenFile
	call ReadHeader
	call ReadPalette
	call CopyPal
	call CopyBitmap
	; Wait for key press
	; Initializes the mouse
	mov ax,0h
	int 33h
	; Show mouse
	mov ax,1h
	int 33h
	mov ah,1
MouseLP :
	mov ax,5h
	int 33h
	cmp dx, 19
	jb MouseLP
	cmp dx,150
	ja MouseLP
	cmp cx,50
	jb MouseLP
	cmp cx,260
	ja MouseLP
	mov ax,2
	int 33h
	ret
endp createStartingPage
proc backround
	push offset frame
	call OpenFile
	call ReadHeader
	call ReadPalette
	call CopyPal
	call CopyBitmap
	ret
endp backround
proc colorPixel;get color then x y cordinate and color the pixel black
	push bp
	mov bp,sp
	mov bh,0h
	mov cx,[bp+6]
	mov dx,[bp+4]
	mov al,[bp+8]
	mov ah,0ch
	int 10h
	pop bp
	ret 6
endp colorPixel
proc line
	push bp;get color first then cordinate
	mov bp,sp
	mov cx,5;loop for color line of pixels to create basic unit for the snake
	mov ax,[bp+6]
lineLoop:
	push cx;keep cx for couting 
	push ax;keep the registor for this function
	
	push [bp+8]
	push ax
	push [bp+4]
	call colorPixel
	pop ax
	pop cx
	inc ax;add 1 to x cordinate
	loop lineLoop
	pop bp
	ret 6
endp line
proc thickPixel;get color 
	push bp
	mov bp,sp
	mov cx,5
	mov ax,[y]
row:
	push cx;keep cx as is for the Counting
	push ax;keep ax for the after 
	push [bp+4]
	push [x]
	push ax
	call line
	
	pop ax;get back the function registers values
	pop cx
	
	inc ax
	loop row
	pop bp
	ret 2
endp thickPixel
proc waitrSec
	; wait for first change in timer
	mov ax, 40h
	mov es, ax
	mov ax, [Clock]
FirstTick :
	cmp ax, [Clock]
	je FirstTick
	mov cx, 20 ; 20.055sec = ~10sec
DelayLoop:
	mov ax, [Clock]
Tick :
	cmp ax, [Clock]
	je Tick
	loop DelayLoop
	ret
endp waitrSec

proc snake
	mov cx,100
	lea di,[x]
	mov bx,5
	jmp moving
changeDir:
	dec cx
	mov ah, 0
	int 16h
	cmp ah,77;check if right buttom
	je rightButtom
	cmp ah,75;check if left buttom
	je leftButtom
	cmp ah,72;check if up buttom
	je upButtom
	cmp ah,80;check if down buttom
	je downButtom
	cmp ah,1;check if escape
	je escapeButtom
	jmp moving;if other buttom keep going 
escapeButtom:
	ret
upButtom:
	lea di,[y]
	mov bx,-5
	jmp moving
downButtom:
	lea di,[y]
	mov bx,5
	jmp moving
leftButtom:
	lea di,[x]
	mov bx,-5
	jmp moving
rightButtom:
	lea di,[x]
	mov bx,5
moving:
	push cx;keep cx as is for couting
	push di;keep di as is for diraction
	push bx;keep bx as is for diraction
	push black
	call thickPixel
	call waitrSec
	push green
	call thickPixel
	pop bx
	pop di
	mov ax,[word ptr di]
	add ax,bx
	mov [word ptr di],ax
	pop cx
	mov ah,1
	int 16h
	jnz changeDir
	loop moving
	ret 
endp snake
start :
	mov ax, @data
	mov ds, ax
	; Graphic mode
	mov ax, 13h
	int 10h
	call createStartingPage
	call backround
	call snake
	mov ah , 1
	int 21h
	
exit :
	; Back to text mode
	mov ah, 0
	mov al, 2
	int 10h
	; Back to text mode
	mov ah, 0
	mov al, 2
	int 10h
	mov ax, 4c00h
	int 21h
END start
