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
	red equ 1
	Clock equ es:6Ch
	StartMessage db 'Counting 10 seconds. Start...',13,10,'$'
	EndMessage db '...Stop.',13,10,'$'
	score dw 3
	diraction dw "+x"
	maxSize dw 400;in bytes
	erasePixels dw 400 dup(?)
	front dw 0
	tail dw 0;the index of the last cordinate
	xToRemove dw ?
	yToRemove dw ?
	isEaten dw 0
	xApple dw ?
	yApple dw ?
	Loose dw 0
CODESEG
proc createRandomCordinate
	mov dx, [Clock] ; read timer counter
	mov ax, [word cs:bx] ; read one byte from memory
	xor ax, dx ; xor memory and counter
	and ax, 0FFh ; leave results between 0-255
	ret 
endp createRandomCordinate
proc modluAx
	cmp ax, [maxSize]
	jna skipSub
	sub ax,[maxSize]
skipSub:
	ret 
endp modluAx
proc insertPixelForErase ;get x y cordinate
	push bp
	mov bp,sp
	mov ax,[tail]
	lea di,[erasePixels]
	add di,ax;adress for insert
	mov bx, [bp+6]
	mov [word ptr di],bx;insert x cordinate
	add ax,2
	call modluAx
	lea di,[erasePixels]
	add di , ax
	mov bx,[bp+4]
	mov [word ptr di ],bx;insert y cordinte
	add ax,2
	call modluAx
	mov [tail],ax;update tail for next insert
	pop bp
	ret 4
endp insertPixelForErase
proc getPixelToRemove
	lea di , [erasePixels]
	mov ax,[front]
	add di,ax
	mov bx,[word ptr di ]; get the x to remove
	mov [xToRemove],bx
	add ax,2
	call modluAx
	lea di, [erasePixels]
	add di, ax
	mov bx,[word ptr di]
	mov [yToRemove],bx
	add ax,2
	call modluAx
	mov [front],ax
	ret
endp getPixelToRemove
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
	mov cx, 5 
DelayLoop:
	mov ax, [Clock]
Tick :
	cmp ax, [Clock]
	je Tick
	loop DelayLoop
	ret
endp waitrSec
proc checkIfAppleEaten
	mov bh,0h
	mov cx,[x]
	mov dx,[y]
	mov ah,0Dh
	int 10h ; return al the pixel value read
	cmp al,red
	jne notEated
	mov ax,1
	mov [isEaten] ,ax
	jmp notLoose
notEated:
	cmp al,black
	jne notLoose
	mov ax,1
	mov [Loose],ax
notLoose:
	ret
endp checkIfAppleEaten
proc moveSnake

	cmp [diraction],"+X"
	je plusX
	cmp [diraction], "-X"
	je minusX
	cmp [diraction],"+Y"
	je plusY
	cmp [diraction],"-Y"
	je minusY
plusX:
	mov ax,[x]
	add ax,5
	mov [x],ax
	call checkIfAppleEaten
	ret
minusX:
	mov ax,[x]
	sub ax,5
	mov [x],ax
	call checkIfAppleEaten
	ret
plusY:
	mov ax,[y]
	add ax,5
	mov [y],ax
	call checkIfAppleEaten
	ret
minusY:
	mov ax,[y]
	sub ax,5
	mov [y],ax
	call checkIfAppleEaten
	ret
endp moveSnake
proc paintSnake
	mov cx,[score]
paintSnakeLoop:
	push cx
	push black
	call thickPixel
	push [x]
	push [y]
	call insertPixelForErase
	call moveSnake
	pop cx
	loop paintSnakeLoop
	ret
endp paintSnake
proc removeTailOfSnake
	call getPixelToRemove
	push [x]
	push [y]
	mov bx,[xToRemove]
	mov [x],bx
	mov bx,[yToRemove]
	mov [y],bx
	push green
	call thickPixel
	pop [y]
	pop [x]
	ret
endp removeTailOfSnake
proc changeDirProc
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
	ret;for other buttoms
escapeButtom:
	pop ax;release returinig adress
	jmp exit 
upButtom:
	cmp [diraction],"+Y"
	je notValid
	cmp [diraction],"-Y"
	je notValid
	mov ax,"-Y"
	jmp endChangeDirProc
downButtom:
	cmp [diraction],"+Y"
	je notValid
	cmp [diraction], "-Y"
	je notValid
	mov ax,"+Y"
	jmp endChangeDirProc
leftButtom:
	cmp [diraction],"+X"
	je notValid
	cmp [diraction], "-X"
	je notValid
	mov ax, "-X"
	jmp endChangeDirProc
rightButtom:
	cmp ax,"+X"
	je notValid
	cmp ax,"-X"
	je notValid
	mov ax,"+X"
notValid:
endChangeDirProc:
	mov [diraction],ax
	ret
endp changeDirProc
proc drawApple
	push [x]
	push [y]
	mov bx,[xApple]
	mov [x],bx
	mov bx,[yApple]
	mov [y],bx
	push red
	call thickPixel
	pop [y]
	pop [x]
	ret
endp drawApple
proc eraseApple
	push [x]
	push [y]
	mov ax,[xApple]
	mov [x],ax
	mov ax,[yApple]
	mov [y],ax
	push green
	call thickPixel
	pop [y]
	pop [x]
	ret
endp eraseApple
proc snake
	call createRandomCordinate
	mov [xApple],ax
	call createRandomCordinate
	mov [yApple],ax
	call paintSnake
	call changeDirProc
	call drawApple
	jmp moving
changeDir:
	call changeDirProc
moving:
	push black
	call thickPixel
	cmp [Loose],1
	je LooseLable
	call waitrSec
	push [x]
	push [y]
	call insertPixelForErase
	call moveSnake
	cmp [isEaten],1
	je dontRemoveTailOfSnake
	call removeTailOfSnake
	jmp dontDrawApple
dontRemoveTailOfSnake:
	call eraseApple
recreateRandomCordinate:
	call createRandomCordinate
	sub ax,[xApple]
	cmp ax,30
	jb recreateRandomCordinate
	mov [xApple],ax
	call createRandomCordinate
	sub ax,[xApple]
	cmp ax,30
	jb recreateRandomCordinate
	mov [yApple],ax
	call drawApple
	mov ax,[score]
	inc ax
	mov [score],ax
	mov ax,0
	mov [isEaten],ax
dontDrawApple:
	mov ah,1
	int 16h
	jz skip
	jmp changeDir
skip:	
	loop moving
LooseLable:
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
