	xref	_WIDTH
	xref	_HEIGHT
BILINEAR	EQU	1
	
	xdef _draw_sprite8b
_draw_sprite8b
	move.l	4(sp),a1
	movem.l	d2-d7/a2-a6,-(sp)
	xref	image_data
	lea		image_data,a0
	xref	_PIXMRG8
	lea		_PIXMRG8,a6
	
	moveq	#0,d0		; fixed src_x
	moveq	#0,d1		; fixed src_y
	moveq	#0,d2		; dest_x
	moveq	#0,d3		; dest_y
	
	; calc angles
	xref	ds_angle
	move.l	ds_angle,d6
	xref	ds_zoom
	move.l	ds_zoom,d4	; fixed dx
	move.l	D4,D5	; fixed dy

	xref	sin_cos_table
	lea		sin_cos_table,a2
	muls	720(a2,d6*2),d4	; cos
	asr.l	#4,d4
	muls	000(a2,d6*2),d5	; sin
	asr.l	#4,d5

	move.l	D4,A4
	move.l	D5,A5

	move.l  #$00008000,D7	   ; fixed start_x
	move.l  #$00008000,A3	   ; fixed start_y
	
	move.l  _HEIGHT,D3
	subq.l  #1,d3
.ds_loop1:
	move.l	d7,d0				; src_x = start_x 
	move.l	a3,d1				; src_y = start_y

	move.l  _WIDTH,d2	      	; dest_x
	subq.l  #1,d2

.ds_loop2:
	move.l  D1,D6
	
*	dc.w    %0100110011000000,%0110000000101001  ; PERM #0051,D0,D6
	swap	d0
	lsr.l	#8,d6
	move.b	d0,d6
	swap	d0
	
	andi.l  #$FFFF,D6

* no bilinear
*	move.w  (a0,d6.l*2),D5
* bilinear
*	dc.w    $FE30,$042B,$6a00  ; pixmrg (A0,D6.L*2),D0,D4
*	dc.w    $FE31,$052B,$6a00  ; pixmrg (A1,D6.L*2),D0,D5
*	swap D4
*	move.w D5,D4
*	dc.w    $FE04,$152B	; pixmrg D4,D1,D5

	ifeq	BILINEAR
	move.l	(a0,D6.L*4),(a1)+
	bra		.zzz
	endc

	lea		(a0,D6.L*4),a2
	
	
	move.w	d0,d6
	lsr.w	#8-PREC,d6
	
	move.b	0000+5(a2),d6
	move.b	(a6,d6.w),d4
	move.b	1024+5(a2),d6
	move.b	(a6,d6.w),d5
	move.b	0000+6(a2),d6
	lsl.l   #8,d4
	move.b	(a6,d6.w),d4
	move.b	1024+6(a2),d6
	lsl.l   #8,d5
	move.b	(a6,d6.w),d5
	move.b	0000+7(a2),d6
	lsl.l   #8,d4
	move.b	(a6,d6.w),d4
	move.b	1024+7(a2),d6
	lsl.l   #8,d5
	move.b	(a6,d6.w),d5
	
	eor.w	#(1<<(8+PREC))-1,d6
	
	move.b	0000+3(a2),d6
	add.b	(a6,d6.w),d4
	move.b	1024+3(a2),d6
	add.b	(a6,d6.w),d5
	ror.l   #8,d4
	ror.l   #8,d5
	move.b	0000+2(a2),d6
	add.b	(a6,d6.w),d4
	move.b	1024+2(a2),d6
	add.b	(a6,d6.w),d5
	ror.l   #8,d4
	ror.l   #8,d5
	move.b	0000+1(a2),d6
	add.b	(a6,d6.w),d4
	move.b	1024+1(a2),d6
	add.b	(a6,d6.w),d5
	
	move.w	d1,d6
	lsr.w	#8-PREC,d6
	move.b	d5,d6
	move.b	(a6,d6.w),d5
	rol.l   #8,d5
	move.b	d5,d6
	move.b	(a6,d6.w),d5
	rol.l   #8,d5
	move.b	d5,d6
	move.b	(a6,d6.w),d5
	
	eor.w	#(1<<(8+PREC))-1,d6
	
	move.b	d4,d6
	move.b	(a6,d6.w),d4
	rol.l   #8,d4
	move.b	d4,d6
	move.b	(a6,d6.w),d4
	rol.l   #8,d4
	move.b	d4,d6
	move.b	(a6,d6.w),d4
	
	add.l   d4,d5
	move.l	d5,(a1)+
.zzz
	add.l   A5,D1		; + Y step
	add.l   A4,D0		; + X Step

    dbf     d2,.ds_loop2

    sub.l   A5,d7	   ; start_x -= dy
    add.l   A4,a3	   ; start_y += dx
	
	move.l	_WIDTH,d0
	lsl.l	#2,d0
	xref	_rowbytes
	sub.l	_rowbytes,d0
	sub.l	d0,a1


    dbf     d3,.ds_loop1
	movem.l	(sp)+,d2-d7/a2-a6
	rts

	xdef _draw_sprite8b_
_draw_sprite8b_
	move.l	4(sp),a1
	movem.l	d2-d7/a2-a6,-(sp)
	xref	image_data
	lea	image_data,a0
	xref	_PIXMRG8
	lea	_PIXMRG8,a6
	
	moveq	#0,d0		; fixed src_x
	moveq	#0,d1		; fixed src_y
	moveq	#0,d2		; dest_x
	moveq	#0,d3		; dest_y
	
	; calc angles
	xref	ds_angle
	move.l	ds_angle,d6
	xref	ds_zoom
	move.l	ds_zoom,d4	; fixed dx
	move.l	D4,D5	; fixed dy

	xref	sin_cos_table
	lea		sin_cos_table,a2
	muls	720(a2,d6*2),d4	; cos
	asr.l	#4,d4
	muls	000(a2,d6*2),d5	; sin
	asr.l	#4,d5

	move.l	D4,A4
	move.l	D5,A5

	move.l  #$00008000,D7	   ; fixed start_x
	move.l  #$00008000,A3	   ; fixed start_y
	
	move.l  _HEIGHT,D3
	subq.l  #1,d3
.ds_loop1:
	move.l	d7,d0				; src_x = start_x 
	move.l	a3,d1				; src_y = start_y

	move.l  _WIDTH,d2	      	; dest_x
	subq.l  #1,d2

.ds_loop2:
	move.l  D1,D6
	
*	dc.w    %0100110011000000,%0110000000101001  ; PERM #0051,D0,D6
	swap	d0
	lsr.l	#8,d6
	move.b	d0,d6
	swap	d0
	
	andi.l  #$FFFF,D6

* no bilinear
*	move.w  (a0,d6.l*2),D5
* bilinear
*	dc.w    $FE30,$042B,$6a00  ; pixmrg (A0,D6.L*2),D0,D4
*	dc.w    $FE31,$052B,$6a00  ; pixmrg (A1,D6.L*2),D0,D5
*	swap D4
*	move.w D5,D4
*	dc.w    $FE04,$152B	; pixmrg D4,D1,D5

	ifeq	BILINEAR
	move.l	(a0,D6.L*4),(a1)+
	bra	.zzz
	endc

	lea	(a0,D6.L*4),a2
	
	
	move.w	d0,d6
	lsr.w	#8-PREC,d6
	
	move.b	0000+4(a2),d6
	move.b	(a6,d6.w),d4
	move.b	1024+4(a2),d6
	move.b	(a6,d6.w),d5
	move.b	0000+5(a2),d6
	lsl.l   #8,d4
	move.b	(a6,d6.w),d4
	move.b	1024+5(a2),d6
	lsl.l   #8,d5
	move.b	(a6,d6.w),d5
	move.b	0000+6(a2),d6
	lsl.l   #8,d4
	move.b	(a6,d6.w),d4
	move.b	1024+6(a2),d6
	lsl.l   #8,d5
	move.b	(a6,d6.w),d5
	
	eor.w	#(1<<(8+PREC))-1,d6
	
	move.b	0000+2(a2),d6
	add.b	(a6,d6.w),d4
	move.b	1024+2(a2),d6
	add.b	(a6,d6.w),d5
	ror.l   #8,d4
	ror.l   #8,d5
	move.b	0000+1(a2),d6
	add.b	(a6,d6.w),d4
	move.b	1024+1(a2),d6
	add.b	(a6,d6.w),d5
	ror.l   #8,d4
	ror.l   #8,d5
	move.b	0000+0(a2),d6
	add.b	(a6,d6.w),d4
	move.b	1024+0(a2),d6
	add.b	(a6,d6.w),d5
	
	move.w	d1,d6
	lsr.w	#8-PREC,d6
	move.b	d5,d6
	move.b	(a6,d6.w),d5
	rol.l   #8,d5
	move.b	d5,d6
	move.b	(a6,d6.w),d5
	rol.l   #8,d5
	move.b	d5,d6
	move.b	(a6,d6.w),d5
	
	eor.w	#(1<<(8+PREC))-1,d6
	
	move.b	d4,d6
	move.b	(a6,d6.w),d4
	rol.l   #8,d4
	move.b	d4,d6
	move.b	(a6,d6.w),d4
	rol.l   #8,d4
	move.b	d4,d6
	move.b	(a6,d6.w),d4
	
	add.l   d4,d5
	lsl.l	#8,d5
	move.l	d5,(a1)+
.zzz
	add.l   A5,D1		; + Y step
	add.l   A4,D0		; + X Step

	dbf     d2,.ds_loop2

	sub.l   A5,d7		; start_x -= dy
	add.l   A4,a3	   	; start_y += dx
	
	move.l	_WIDTH,d0
	lsl.l	#2,d0
	xref	_rowbytes
	sub.l	_rowbytes,d0
	sub.l	d0,a1


    dbf     d3,.ds_loop1
	movem.l	(sp)+,d2-d7/a2-a6
	rts
