screen_width       EQU WIDTH
screen_height      EQU HEIGHT
screen_depth       EQU 6
bitplane_size      EQU (screen_width*screen_height)/8+8
chunky_buffer_size EQU (screen_width*screen_height)
planar_buffer_size EQU ((screen_width*screen_height)/8+8)*screen_depth
header		   EQU 128

PIXMGR				equ	1

image_buffer_adr EQU $08104000
fastmem_adr    EQU $08000000
; 256 K
screen_adr     EQU $40000	

PLL_CS	   EQU $1	    ; 
PLL_CSn	  EQU $0	    ; 
PLL_CLK	  EQU $2	    ; 
PLL_CLKn	 EQU $0	    ; 
PLL_MOSI	 EQU $4	    ; 
PLL_CONF	 EQU $8	    ; 
PLL_SIZE	 EQU 18	    ; 18 bytes
PLL_MAGIC	EQU $43430000     ; Selector

SAGA_FBADDR	      EQU $dff1ec       ; Video Address
SAGA_FBMODE	      EQU $dff1f4       ; Video Mode
SAGA_PLLW	EQU $dff1f8       ; Video PLLW
SAGA_PLLR	EQU $dff1fa       ; Video PLLR
SAGA_HPIXEL	      EQU $dff300       ; Video Modeline
SAGA_CLUT	EQU $dff400       ; Video Color Lookup Table



   section .chipram
	dc.l	$11144ef9
	dc.l 	$00f80008
	

j:
	clr.b  $bfa001
	clr.b  $bfa201
	clr.b  $bfe001
	move.b #3,$bfe201





;***  pull out from ROM to FAST RAM
	lea     $0f80000,A0
	lea     fastmem_adr,A1
	move.w  #$C000,D0	      ; copy 160K
cpy2:   move.l  (A0)+,(A1)+
	move.l  (A0)+,(A1)+
	dbf     d0,cpy2

	jmp     fastmem_adr+fastmem


fastmem:
	move.w  #$0700,SR
	move.l	#$080F0000,A7
	lea	$dff000,A5
	lea	DATA(pc),A6

	move.w	#$7fff,$09a(a5)		; intena off
	move.w	#$7fff,$096(a5)		; all dma off


; ******** Overlay off
	move.b #$3,$BFE201
	move.b #$2,$BFE001
	move.b #$0,$bfe801  ; start TOD timer


	lea     PLLDATA(pc),a0	     ; Set PLL    
	bsr.w   SAGA_SetPLL	    ; 


	lea     MODELINE(pc),a0	    ; Set Modeline
	bsr.w   SAGA_SetModeline	       ; 

	move.l  #image_buffer_adr,SAGA_FBADDR	 ; Set FrameBuffer
	move.w  #$0002,SAGA_FBMODE     ; Enable Video 



;******** BMP to bigendian RAW
	lea     image_data+70(pc),a0
	move.l  #256*256,d0
conv
	move.w	(a0),D1
	ror.w	#8,D1
	move.w	D1,(a0)+
	subq.l	#1,D0
	bne	conv	

;***********************************************
loop:

	bsr	draw_sprite


	bsr     update_rotate

	bra	loop

;***********************************************

	




; ***********************************************

SAGA_SetPLL:
    add.l   #PLL_SIZE,a0	   ; End of array
    move.w  #PLL_SIZE-1,d3	 ; for(d3=17; d3>=0; d3--) {
.bytes		     ;   
    move.b  -(a0),d1	       ;   Load byte
    move.l  #PLL_MAGIC+PLL_CSn+PLL_CLKn,d0 ;   
    move.l  d0,SAGA_PLLW	   ;   
    moveq   #8-1,d2		;   for(d2=7; d2>=0; d2--) {
.bits		      ;     
    lsr.b   #1,d1		  ;     Load bit
    scs.b   d0		     ;     
    andi.w  #PLL_MOSI,d0	   ;     
    move.l  d0,SAGA_PLLW	   ;     
    ori.w   #PLL_CLK,d0	    ;     
    move.l  d0,SAGA_PLLW	   ;     Write bit
    dbf     d2,.bits	       ;   }
    dbf     d3,.bytes	      ; }
    move.l  #PLL_MAGIC+PLL_CS+PLL_CLKn,d0  ; 
    move.l  d0,SAGA_PLLW	   ; 
    move.w  #PLL_CS+PLL_CLK,d0	     ; 
    move.l  d0,SAGA_PLLW	   ; 
    move.w  #PLL_CS+PLL_CLKn+PLL_CONF,d0   ; 
    move.l  d0,SAGA_PLLW	   ; 
    move.w  #PLL_CS+PLL_CLK+PLL_CONF,d0    ; 
    move.l  d0,SAGA_PLLW	   ; 
    moveq.l #128-1,d1	      ; for(d1=127; d1>=0; d1--) {
.extra		     ;   
    move.w  #PLL_CS+PLL_CLKn,d0	    ;   
    move.l  d0,SAGA_PLLW	   ;   
    move.w  #PLL_CS+PLL_CLK,d0	     ;   
    move.l  d0,SAGA_PLLW	   ;   
    dbf     d1,.extra	      ; }
    rts   

; ***********************************************

SAGA_SetModeline:
    lea     SAGA_HPIXEL,a1	 ; Destination
    move.w  (a0)+,(a1)+	    ; HPIXEL
    move.w  (a0)+,(a1)+	    ; HSSTRT
    move.w  (a0)+,(a1)+	    ; HSSTOP
    move.w  (a0)+,(a1)+	    ; HTOTAL
    move.w  (a0)+,(a1)+	    ; VPIXEL
    move.w  (a0)+,(a1)+	    ; VSSTRT
    move.w  (a0)+,(a1)+	    ; VSSTOP
    move.w  (a0)+,(a1)+	    ; VTOTAL
    move.w  (a0)+,(a1)+	    ; HVSYNC
    rts  

; ***********************************************


draw_sprite:	
	lea	image_buffer_adr,A1
draw_sprite2
	move.l	textureptr-DATA(A6),a0
	moveq	#0,d0			; fixed src_x
	moveq	#0,d1			; fixed src_y
	moveq	#0,d2			; dest_x
	moveq	#0,d3			; dest_y
	
	; calc angles
	move.l	ds_angle-DATA(A6),d6
	move.l	ds_zoom-DATA(A6),d4	; fixed dx
	move.l	D4,D5			; fixed dy

	lea	sin_cos_table(pc),a2
	lea	sin_cos_table+720(pc),a3
	muls	(a3,d6*2),d4	; cos
	asr.l	#4,d4
     
	muls	(a2,d6*2),d5	; sin
	asr.l	#4,d5

	move.l	D4,A4
	move.l	D5,A5


    move.l  #$00008000,startX-DATA(A6)	; fixed start_x
    move.l  #$00008000,startY-DATA(A6)	; fixed start_y

 	move.l	a1,A3
    move.w  #screen_height,CountRow-DATA(A6)

.ds_loop1:
    move.l  startX-DATA(A6),D0			; src_x = start_x       
    move.l  startY-DATA(A6),D1			; src_y = start_y


	dc.w	$7141					; BANK
	move.w  #screen_width-1,D7     	; move.w #,E7 dest_x
.ds_loop2:
	bfextu  D1{8:6},D4				; Y
	move.l	D1,D3					; fused*
	addi.l	#$10000,D3				; Y+1		

	bfextu  D0{8:6},D5				; X
	move.l	D0,D7					; fused*
	addi.l	#$10000,D7				; X+1		

	bfextu  D7{8:6},D2				; X+1
	lsl.w	#6,D4			

	dc.w	$FE3F,$0A03,$0123,$45CD	; VPERM  D3,D0,E2
	dc.w    $FF01,$1004	    		; VSTORE D1,E9!

	dc.w	$FE3F,$7B03,$0123,$45CD	; VPERM D3,D7,E3
	move.l	D4,D6					; fused*
	or.b	D5,D6					; PTR-(Y0,X0)

	bfextu  D3{8:6},D3				; Y+1
	or.b	D2,D4					; PTR-(Y0,X1)

	dc.w	$FE3F,$0801,$0123,$45CD	; VPERM D1,D0,E0
	lsl.w	#6,D3					; Y1

	dc.w	$FE3F,$7901,$0123,$45CD	; VPERM D1,D7,E1
	move.l	D3,D7					; Fused
	or.b	D5,D7					; PTR (Y1,X0)

	dc.w    $FE30,$8C3B,$6e00       ; dtx (A0,D6.L*8),E0,E4
	or.b	D2,D3					; PTR (Y1,X1)

	dc.w    $FE30,$9D3B,$4e00       ; dtx (A0,D4.L*8),E1,E5
	dc.w    $Fe08,$0004	     		; VSTORE D0,E0!

	dc.w    $FE0C,$0D2B   			; pixmrg E4,D0,E5*   Merge X0 X1
	; *

	dc.w    $FE30,$AC3B,$7e00       ; dtx (A0,D7.L*8),E2,E4
	add.l   A4,D0					; + X Step
 
	dc.w    $FE30,$B63B,$3e00       ; dtx (A0,D3.L*8),E3,D6
	add.l   A5,D1					; + Y step

	dc.w    $FE0C,$862B				; pixmrg E4,E0!,D6   Merge X2 X3
	; *

	dc.w    $FE8D,$162B				; pixmrg E5,E9!,D6
	; *

	move.l  D6,(A3)+	 	; move pixel to screen
	dc.w 	$7141			; BANK
	dbf     D7,.ds_loop2	; DBRA E7

	move.l  startX-DATA(A6),D5
	sub.l   A5,D5
	move.l	D5,startX-DATA(A6)		; start_x -= dy

	move.l  startY-DATA(A6),D5
	add.l   A4,D5
	move.l	D5,startY-DATA(A6)		; start_y += dx

	subq.w	#1,CountRow-DATA(A6)
	bne		.ds_loop1

	rts


;******************************************

pixmrg 
	rsreset	3*4
	rs.l	4
.k	rs.w	1
.pix1	rs.w	1
.pix2	rs.w	1
	movem.l d0-d1/a1,-(sp)
	lea	_PIXMRG,a1
	moveq	#0,d0
	
	move.w  .k(sp),d0
	lsl.l	#PREC,d0
	move.w	.pix2(sp),d0
	move.w	(a1,d0.l*2),d1
	
	eor.l	#(1<<(16+PREC))-1,d0
	move.w	.pix1(sp),d0
	add.w	(a1,d0.l*2),d1
	
	move.w	d1,.k(sp)	; return value
	movem.l (sp)+,d0-d1/a1
	rts
	
;**************** update koordinates *******	
update_rotate:
	move.l	zoom_dir-DATA(A6),d0
	move.l	ds_zoom-DATA(A6),d1
	add.l	d0,d1
	move.l	d1,ds_zoom-DATA(A6)

; manage zoom	
	tst	d0
	blt.s	ml_negative
	cmp	#550*640/WIDTH,d1
	blt	ml_skip
ml_change:
	neg.l	D0
	move.l	d0,zoom_dir-DATA(A6)
	bra.s	ml_skip
ml_negative:
	cmp	#80,d1
	bgt.s	ml_skip
	neg.l	D0
	move.l	d0,zoom_dir-DATA(A6)

	move.l  textureptr-DATA(A6),D0
	move.l  textureptr2-DATA(A6),textureptr-DATA(A6)
	move.l  textureptr3-DATA(A6),textureptr2-DATA(A6)
	move.l  textureptr4-DATA(A6),textureptr3-DATA(A6)
	move.l  textureptr5-DATA(A6),textureptr4-DATA(A6)
	move.l  textureptr6-DATA(A6),textureptr5-DATA(A6)
	move.l  textureptr7-DATA(A6),textureptr6-DATA(A6)
	move.l	D0,textureptr7-DATA(A6)

ml_skip:

	move.l	ds_angle-DATA(A6),d0
	addq.l	#1,d0
	cmp.w	#360*4,d0
	blt.s	ml_skip2
	moveq	#0,d0
ml_skip2:
	move.l	d0,ds_angle-DATA(A6)

	rts


sin_cos_table:
	incbin	"data/sincos3.x"
font:
  dc.b	%01111100
  dc.b	%10000110
  dc.b	%10001010
  dc.b	%10010010
  dc.b	%10100010
  dc.b	%11000010
  dc.b	%01111100
  dc.b $0

  dc.b	%00011000
  dc.b	%00111000
  dc.b	%00011000
  dc.b	%00011000
  dc.b	%00011000
  dc.b	%00011000
  dc.b	%01111110
  dc.b $0

  dc.b	%00111100
  dc.b	%01000010
  dc.b	%00000010
  dc.b	%00000100
  dc.b	%00011000
  dc.b	%01100000
  dc.b	%11111110
  dc.b $0

  dc.b	%00111100
  dc.b	%01000010
  dc.b	%00000010
  dc.b	%00001100
  dc.b	%00000010
  dc.b	%01000010
  dc.b	%00111100
  dc.b $0

  dc.b	%00001000
  dc.b	%00011000
  dc.b	%00101000
  dc.b	%01001000
  dc.b	%11111000
  dc.b	%00001000
  dc.b	%00001000
  dc.b $0

  dc.b	%00011110
  dc.b	%00100000
  dc.b	%01000000
  dc.b	%11111100
  dc.b	%00000010
  dc.b	%10000010
  dc.b	%01111100
  dc.b $0

  dc.b	%01111100
  dc.b	%10000000
  dc.b	%10000000
  dc.b	%11111100
  dc.b	%10000010
  dc.b	%10000010
  dc.b	%01111100
  dc.b $0

  dc.b	%01111110
  dc.b	%00000010
  dc.b	%00000100
  dc.b	%00000100
  dc.b	%00001000
  dc.b	%00001000
  dc.b	%00001000
  dc.b $0

  dc.b	%01111100
  dc.b	%10000010
  dc.b	%10000010
  dc.b	%01111100
  dc.b	%10000010
  dc.b	%10000010
  dc.b	%01111100
  dc.b $0

  dc.b	%01111100
  dc.b	%10000010
  dc.b	%10000010
  dc.b	%01111110
  dc.b	%00000010
  dc.b	%00000010
  dc.b	%00011100
  dc.b $0


PLLDATA:    dc.b $08,$40,$60,$00,$02,$81,$40,$2F,$16 ; VAL_PLLDATA
	    dc.b $02,$C1,$20,$00,$08,$00,$02,$00,$00

MODELINE:    dc.w 640,656,752,800,480,490,492,525,3   ; VAL_MODELINE




; *** Data-Section 


zoom_dir:
	dc.l    1
ds_zoom:  dc.l	100
ds_angle: dc.l	0
countX:   dc.w 0
counter:  dc.w 0
counter1: dc.w 0
countY:   dc.w 0	
startX:   dc.l 0
startY:   dc.l 0
CountRow: dc.w 0
REGA7:		dc.l	0
textureptr   dc.l 0
textureptr2  dc.l 0
textureptr3  dc.l 0
textureptr4  dc.l 0
textureptr5  dc.l 0
textureptr6  dc.l 0
textureptr7  dc.l 0

DATA:
image_data:	
	dcb.l	256*256
	dcb.l	256*4

image_data1:	
	incbin "fox.dds"
	ds.w 256
image_data2:	
	incbin "mandrill.dds"
	ds.w 256
image_data3:	
	incbin "wolf.dds"
	ds.w 256
image_data4:	
	incbin "leopard.dds"
	ds.w 256
image_data5:	
	incbin "owl.dds"
	ds.w 256
image_data6:	
	incbin "goat.dds"
	ds.w 256
image_data7:	
	incbin "kitty.dds"
	ds.w 256
;--------------------------------------------------------------	
; NdSam: interface with main.c
;--------------------------------------------------------------	

	xdef _update_rotate080
_update_rotate080
	movem.l d2-d7/a2-a6,-(sp)
	lea		DATA(pc),A6
	bsr 	update_rotate
	movem.l (sp)+,d2-d7/a2-a6
	rts
	
	xdef _update_rotate68k
_update_rotate68k	
	move.l	a6,-(sp)
	lea		DATA(pc),a6
	move.l	zoom_dir-DATA(a6),d0
	move.l	ds_zoom-DATA(a6),d1
	add.l	d0,d1
	move.l	d1,ds_zoom-DATA(a6)

; manage zoom	
	tst	d0
	blt.s	.ml_negative
	cmp		#550*640/WIDTH,d1
	blt		.ml_skip
.ml_change:
	neg.l	D0
	move.l	d0,zoom_dir-DATA(a6)
	bra.s	.ml_skip
.ml_negative:
	cmp		#80,d1
	bgt.s	.ml_skip
	neg.l	D0
	move.l	d0,zoom_dir-DATA(a6)

	move.l  textureptr-DATA(a6),D0
	move.l  textureptr2-DATA(a6),textureptr-DATA(a6)
	move.l  textureptr3-DATA(a6),textureptr2-DATA(a6)
	move.l  textureptr4-DATA(a6),textureptr3-DATA(a6)
	move.l  textureptr5-DATA(a6),textureptr4-DATA(a6)
	move.l  textureptr6-DATA(a6),textureptr5-DATA(a6)
	move.l  textureptr7-DATA(a6),textureptr6-DATA(a6)
	move.l	D0,textureptr7-DATA(a6)
	
	bsr		uncompress_texture

.ml_skip:

	move.l	ds_angle-DATA(a6),d0
	addq.l	#1,d0
	cmp.w	#360*4,d0
	blt.s	.ml_skip2
	moveq	#0,d0
.ml_skip2:
	move.l	d0,ds_angle-DATA(a6)

	move.l	(sp)+,a6
	rts
	
	xdef _draw_sprite080
_draw_sprite080
    move.l 4(sp),a1
	movem.l d2-d7/a2-a6,-(sp)
	lea	DATA(pc),a6
	bsr draw_sprite2
	movem.l (sp)+,d2-d7/a2-a6
	rts
	
	xdef _draw_sprite68k
_draw_sprite68k
	move.l	4(sp),a1
	movem.l	d2-d7/a2-a6,-(sp)
	lea		image_data(pc),a0
	lea		_PIXMRG,a6
	
	moveq	#0,d0		; fixed src_x
	moveq	#0,d1		; fixed src_y
	moveq	#0,d2		; dest_x
	moveq	#0,d3		; dest_y
	
	; calc angles
	move.l	ds_angle(pc),d6
	move.l	ds_zoom(pc),d4	; fixed dx
	move.l	D4,D5	; fixed dy


	lea	sin_cos_table(pc),a2
	muls	720(a2,d6*2),d4	; cos
	asr.l	#4,d4
	muls	000(a2,d6*2),d5	; sin
	asr.l	#4,d5

	move.l	D4,A4
	move.l	D5,A5

	move.l  #$00008000,D7	   ; fixed start_x
	move.l  #$00008000,A3	   ; fixed start_y

	move.w  #screen_height-1,D3
.ds_loop1:
	move.l	d7,d0				; src_x = start_x 
	move.l	a3,d1				; src_y = start_y

	move.w  #screen_width-1,d2	      ; dest_x

.ds_loop2:
	move.l  D1,D6
	
*	dc.w    %0100110011000000,%0110000000101001  ; PERM #0051,D0,D6
	lsr.l	#8,d6
	swap	d0
	move.b	d0,d6
	swap	d0
	
	andi.l  #$FFFF,D6

* no bilinear
*	move.w  (a0,d6.l*2),D5

* bilinear
*	dc.w    $FE30,$042B,$6a00  ; pixmrg (A0,D6.L*2),D0,D4
*	dc.w    $FE31,$052B,$6a00  ; pixmrg (A1,D6.L*2),D0,D5

	lea		(a0,D6.L*4),a2
	
	ifeq	PIXMGR
	move.l	(a2),d5
	bra		.zzz
	endc
	
	move.w	d0,d6
	lsl.l	#PREC,d6
	
	move.w	0000+4(a2),d6
	move.w	(a6,d6.l*2),d4
	swap	d4
	move.w	0000+6(a2),d6
	move.w	(a6,d6.l*2),d4
	
	move.w	1024+4(a2),d6
	move.w	(a6,d6.l*2),d5
	swap	d5
	move.w	1024+6(a2),d6
	move.w	(a6,d6.l*2),d5

	eor.l	#(1<<(16+PREC))-1,d6
	
	move.w	0000+2(a2),d6
	add.w	(a6,d6.l*2),d4
	swap	d4
	move.w	0000+0(a2),d6
	add.w	(a6,d6.l*2),d4
	
	move.w	1024+2(a2),d6
	add.w	(a6,d6.l*2),d5
	swap	d5
	move.w	1024+0(a2),d6
	add.w	(a6,d6.l*2),d5		; D4=lo:hi(y) D5=lo:hi(y+1)

*	swap D4
*	move.w D5,D4
*	dc.w    $FE04,$152B	; pixmrg D4,D1,D5

	moveq	#0,d6
	move.w	d1,d6
	lsl.l	#PREC,d6
	
	move.w	d5,d6
	move.w	(a6,d6.l*2),d5
	swap	d5
	move.w	d5,d6
	move.w	(a6,d6.l*2),d5
	
	eor.l	#(1<<(16+PREC))-1,d6
	
	move.w	d4,d6
	move.w	(a6,d6.l*2),d4
	swap	d4
	move.w	d4,d6
	move.w	(a6,d6.l*2),d4
	
	add.l	d4,d5
.zzz
	move.l  D5,(a1)+	 ; move pixel

	add.l   A5,D1		; + Y step
	add.l   A4,D0		; + X Step

    dbf     d2,.ds_loop2

    sub.l   A5,d7	   ; start_x -= dy
    add.l   A4,a3	   ; start_y += dx

    dbf     d3,.ds_loop1
	movem.l	(sp)+,d2-d7/a2-a6
	rts

	xdef _prepare
_prepare:
	lea     image_data1+header(pc),a0
	move.l	A0,textureptr
	bsr	CONVERT

	lea     image_data2+header(pc),a0
	move.l	A0,textureptr2
	bsr	CONVERT

	lea     image_data3+header(pc),a0
	move.l	A0,textureptr3
	bsr	CONVERT

	lea     image_data4+header(pc),a0
	move.l	A0,textureptr4
	bsr	CONVERT

	lea     image_data5+header(pc),a0
	move.l	A0,textureptr5
	bsr	CONVERT

	lea     image_data6+header(pc),a0
	move.l	A0,textureptr6
	bsr	CONVERT

	lea     image_data7+header(pc),a0
	move.l	A0,textureptr7
	bsr	CONVERT

uncompress_texture:
	movem.l	d2-d6/a2-a3,-(sp)
	move.l	#64*64-1,d0
	move.l	textureptr,a0	; a0 = texture
	lea		_PIXMRG,a2
	xref	_RGB23
	lea		_RGB23,a3
.1
	move.l	d0,d1
	lsl.w	#4,d1
	move.b	d0,d1
	lsl.b	#2,d1
	and.w	#%1111110011111100,d1
	lea		image_data,a1
	lea		(a1,d1.l*4),a1		; a1 = image
	
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d3
	moveq	#0,d4
	moveq	#0,d5
*	movem.w	(a0),d2/d3			; d2=col0 d3=col1
	move.w	(a0),d2
	move.w	2(a0),d3
	cmp.l	d3,d2
	bgt.s	.2
; d4=col2=(col0+col1)/2 d5=col3=0
PERC99	set	(1<<PREC)-1
PERC50	set	(1<<(PREC-1))
	move.l	(a3,d2.l*4),d2
	move.l	(a3,d3.l*4),d3
	move.w	d2,d1
	move.w	(PERC50^PERC99)<<17(a2,d1.l*2),d4
	move.w	d3,d1
	add.w	PERC50<<17(a2,d1.l*2),d4
	swap	d2
	swap	d3
	swap	d4
	move.w	d2,d1
	move.w	(PERC50^PERC99)<<17(a2,d1.l*2),d4
	move.w	d3,d1
	add.w	PERC50<<17(a2,d1.l*2),d4
	bra		.3
; d4=col2=(2col0+col1)/3 d5=col3=(col0+2col1)/3
PERC66	set	(2<<PREC)/3
PERC33	set	PERC66^PERC99
.2	
	move.l	(a3,d2.l*4),d2
	move.l	(a3,d3.l*4),d3
	move.w	d2,d1
	move.w	PERC66<<17(a2,d1.l*2),d4
	move.w	PERC33<<17(a2,d1.l*2),d5
	move.w	d3,d1
	add.w	PERC33<<17(a2,d1.l*2),d4
	add.w	PERC66<<17(a2,d1.l*2),d5
	swap	d2
	swap	d3
	swap	d4
	swap	d5
	move.w	d2,d1
	move.w	PERC66<<17(a2,d1.l*2),d4
	move.w	PERC33<<17(a2,d1.l*2),d5
	move.w	d3,d1
	add.w	PERC33<<17(a2,d1.l*2),d4
	add.w	PERC66<<17(a2,d1.l*2),d5
; uncompress pixels
.3
	move.b	7(a0),d6
	bsr.s	uncomp_row
	lea		1024-4*4(a1),a1
	move.b	6(a0),d6
	bsr.s	uncomp_row
	lea		1024-4*4(a1),a1
	move.b	5(a0),d6
	bsr.s	uncomp_row
	lea		1024-4*4(a1),a1
	move.b	4(a0),d6
	bsr.s	uncomp_row
	addq.w	#8,a0
	dbf	d0,.1
* copy first and last line
	lea		image_data,a1
	move.w	#256*4-1,d0
.4
	move.l	(a1)+,256*256*4(a1)
	dbf	d0,.4
	movem.l	(sp)+,d2-d6/a2-a3
	rts
	
; uncompress a row of pixel d6.b = bits
uncomp_row
	bsr.s	uncomp_pix
	bsr.s	uncomp_pix
	bsr.s	uncomp_pix
uncomp_pix
	add.b	d6,d6
	bcs.s	.5
	add.b	d6,d6
	bcs.s	.6
	move.l	d2,(a1)+
	rts
.6
	move.l	d3,(a1)+
	rts
.5
	add.b	d6,d6
	bcs.s	.7
	move.l	d4,(a1)+
	rts
.7
	move.l	d5,(a1)+
	rts
	
CONVERT:
	move.l	A0,A1
	move.w  #64*64-1,d0
.conv
	move.w	(a1),D1
	ror.w	#8,D1
	move.w	D1,(a1)+
	move.w	(a1),D1
	ror.w	#8,D1
	move.w	D1,(a1)+
	addq.l	#4,A1
	dbf		d0,.conv

;*** copy Line 0 to Line 256
	move.l	A0,A1
	add.l	#64*64*8,A1
	moveq	#64-1,D0
.Cop1
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbra	d0,.Cop1
	rts
