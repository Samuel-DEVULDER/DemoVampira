screen_width       EQU 640
screen_height      EQU 360
screen_depth       EQU 6
bitplane_size      EQU (screen_width*screen_height)/8+8
chunky_buffer_size EQU (screen_width*screen_height)
planar_buffer_size EQU ((screen_width*screen_height)/8+8)*screen_depth

image_buffer_adr EQU $08104000
fastmem_adr    EQU $08000000
; 256 K
screen_adr     EQU $40000		

PLL_CS                   EQU $1            ; 
PLL_CSn                  EQU $0            ; 
PLL_CLK                  EQU $2            ; 
PLL_CLKn                 EQU $0            ; 
PLL_MOSI                 EQU $4            ; 
PLL_CONF                 EQU $8            ; 
PLL_SIZE                 EQU 18            ; 18 bytes
PLL_MAGIC                EQU $43430000     ; Selector

SAGA_FBADDR              EQU $dff1ec       ; Video Address
SAGA_FBMODE              EQU $dff1f4       ; Video Mode
SAGA_PLLW                EQU $dff1f8       ; Video PLLW
SAGA_PLLR                EQU $dff1fa       ; Video PLLR
SAGA_HPIXEL              EQU $dff300       ; Video Modeline
SAGA_CLUT                EQU $dff400       ; Video Color Lookup Table



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
        move.w  #$C000,D0              ; copy 160K
cpy2:   move.l  (A0)+,(A1)+
	move.l  (A0)+,(A1)+
        dbf     d0,cpy2

        jmp     fastmem_adr+fastmem


fastmem:
	move.w  #$0700,SR
	move.l	#$080F0000,A7
	lea	$dff000,A5
	lea	DATA(pc),A6

	move.w	#$7fff,$09a(a5)			; intena off
	move.w	#$7fff,$096(a5)			; all dma off


; ******** Overlay off
        move.b #$3,$BFE201
        move.b #$2,$BFE001
        move.b #$0,$bfe801  ; start TOD timer


        lea     PLLDATA(pc),a0             ; Set PLL    
        bsr.w   SAGA_SetPLL                    ; 


        lea     MODELINE(pc),a0            ; Set Modeline
        bsr.w   SAGA_SetModeline               ; 

        move.l  #image_buffer_adr,SAGA_FBADDR                 ; Set FrameBuffer
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
    add.l   #PLL_SIZE,a0                   ; End of array
    move.w  #PLL_SIZE-1,d3                 ; for(d3=17; d3>=0; d3--) {
.bytes                                     ;   
    move.b  -(a0),d1                       ;   Load byte
    move.l  #PLL_MAGIC+PLL_CSn+PLL_CLKn,d0 ;   
    move.l  d0,SAGA_PLLW                   ;   
    moveq   #8-1,d2                        ;   for(d2=7; d2>=0; d2--) {
.bits                                      ;     
    lsr.b   #1,d1                          ;     Load bit
    scs.b   d0                             ;     
    andi.w  #PLL_MOSI,d0                   ;     
    move.l  d0,SAGA_PLLW                   ;     
    ori.w   #PLL_CLK,d0                    ;     
    move.l  d0,SAGA_PLLW                   ;     Write bit
    dbf     d2,.bits                       ;   }
    dbf     d3,.bytes                      ; }
    move.l  #PLL_MAGIC+PLL_CS+PLL_CLKn,d0  ; 
    move.l  d0,SAGA_PLLW                   ; 
    move.w  #PLL_CS+PLL_CLK,d0             ; 
    move.l  d0,SAGA_PLLW                   ; 
    move.w  #PLL_CS+PLL_CLKn+PLL_CONF,d0   ; 
    move.l  d0,SAGA_PLLW                   ; 
    move.w  #PLL_CS+PLL_CLK+PLL_CONF,d0    ; 
    move.l  d0,SAGA_PLLW                   ; 
    moveq.l #128-1,d1                      ; for(d1=127; d1>=0; d1--) {
.extra                                     ;   
    move.w  #PLL_CS+PLL_CLKn,d0            ;   
    move.l  d0,SAGA_PLLW                   ;   
    move.w  #PLL_CS+PLL_CLK,d0             ;   
    move.l  d0,SAGA_PLLW                   ;   
    dbf     d1,.extra                      ; }
    rts   

; ***********************************************

SAGA_SetModeline:
    lea     SAGA_HPIXEL,a1                 ; Destination
    move.w  (a0)+,(a1)+                    ; HPIXEL
    move.w  (a0)+,(a1)+                    ; HSSTRT
    move.w  (a0)+,(a1)+                    ; HSSTOP
    move.w  (a0)+,(a1)+                    ; HTOTAL
    move.w  (a0)+,(a1)+                    ; VPIXEL
    move.w  (a0)+,(a1)+                    ; VSSTRT
    move.w  (a0)+,(a1)+                    ; VSSTOP
    move.w  (a0)+,(a1)+                    ; VTOTAL
    move.w  (a0)+,(a1)+                    ; HVSYNC
    rts  

; ***********************************************


draw_sprite:	

	lea	image_data+70(pc),a0
	lea	image_buffer_adr,A1
draw_sprite2	
	moveq	#0,d0			; fixed src_x
	moveq	#0,d1			; fixed src_y
	moveq	#0,d2			; dest_x
	moveq	#0,d3			; dest_y
	
	; calc angles
	move.l	ds_angle-DATA(A6),d6
	move.l	ds_zoom-DATA(A6),d4	; fixed dx
	move.l	D4,D5		; fixed dy


	lea	sin_cos_table(pc),a2
	lea	sin_cos_table+720(pc),a3
	muls	(a3,d6*2),d4	; cos
	asr.l	#4,d4
     

	muls	(a2,d6*2),d5	; sin
	asr.l	#4,d5

	move.l	D4,A4
	move.l	D5,A5

        move.l  #$00008000,A2                   ; fixed start_x
        move.l  #$00008000,A3                   ; fixed start_y

        move.w  #screen_height-1,D3
ds_loop1:
        move.l  A2,d0                   ; src_x = start_x       
        move.l  A3,d1                   ; src_y = start_y

        move.w  #screen_width-1,d2                      ; dest_x

ds_loop2:
        move.l  D1,D6

		
		
*        dc.w    %0100110011000000,%0110000000101001  ; PERM #0051,D0,D6
		lsr.l	#8,d6
		swap	d0
		move.b	d0,d6
		swap	d0
		
        andi.l  #$FFFF,D6

* no bilinear
*        move.w  (a0,d6.l*2),D4

* bilinear
*        dc.w    $FE30,$042B,$6a00  ; pixmrg (A0,D6.L*2),D0,D4
		move.l (a0,D6.L*2),-(SP)
		move.w D0,-(sp)
		bsr pixmrg
		move.w (sp),d4

                               

*        dc.w    $FE31,$052B,$6a00  ; pixmrg (A1,D6.L*2),D0,D5
		move.l 512(a0,D6.L*2),2(SP)
		move.w D0,(SP)
		bsr pixmrg
		move.w (sp),d5
                              

		swap D4
		move.w D5,D4
*        dc.w    $FE04,$152B        ; pixmrg D4,D1,D5
		move.l d4,2(sp)
		move.w d1,(sp)
		bsr pixmrg
		move.w (sp),d5

		addq.w #6,sp
		
	xref 	_RGB16PC
	tst.b	_RGB16PC
	beq.s	.noswap1
	ror.w	#8,d5
.noswap1		
    move.w  D5,(a1)+         ; move pixel

        add.l   A5,D1                                ; + Y step
        add.l   A4,D0                                ; + X Step

    dbf     d2,ds_loop2

    sub.l   A5,A2                   ; start_x -= dy
    add.l   A4,A3                   ; start_y += dx

    dbf     d3,ds_loop1
	rts


;******************************************

PREC	set		5

pixmrg 
		rsreset	3*4
		rs.l	4
.k		rs.w	1
.pix1	rs.w	1
.pix2	rs.w	1
		movem.l d0-d1/a1,-(sp)
		xref	_PIXMRG
		lea		_PIXMRG,a1
		moveq	#0,d0
		
        move.w  .k(sp),d0
		lsl.l	#PREC,d0
		move.w	.pix2(sp),d0
		move.w	(a1,d0.l*2),d1
		
		eor.l	#(1<<(16+PREC))-1,d0
		move.w	.pix1(sp),d0
		add.w	(a1,d0.l*2),d1
		
        move.w	d1,.k(sp)		; return value
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
	cmp	#600,d1
	blt.s	ml_skip
ml_change:
	neg.l	D0
	move.l	d0,zoom_dir-DATA(A6)
	bra.s	ml_skip
ml_negative:
	cmp	#100,d1
	blt.s	ml_change
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
startX:   dc.w 0
startY:   dc.w 0
REGA7:	dc.l	0


DATA:
image_data:	
	incbin "data/256x256.bmp"
	dcb.w	256
	
	xdef _update_rotate
_update_rotate
	movem.l d2-d7/a2-a6,-(sp)
	lea	DATA(pc),A6
	bsr update_rotate
	movem.l (sp)+,d2-d7/a2-a6
	rts

	xdef _draw_sprite
_draw_sprite
    move.l 4(sp),a1
	movem.l d2-d7/a2-a6,-(sp)
	lea	image_data+70(pc),a0
	lea	DATA(pc),A6
	bsr draw_sprite2
	movem.l (sp)+,d2-d7/a2-a6
	rts

		
	xdef _prepare
_prepare:
	lea	image_data+70(pc),a0
	
	move.l  #256*256,d0
.1
	move.w	(a0),D1
	ror.w	#8,D1
	move.w	D1,(a0)+
	subq.l	#1,D0
	bne	.1

	moveq	#0,d0
	not.b	d0
.2
	move.w	-256*256*2(a0),(a0)+
	dbf		d0,.2
		rts
