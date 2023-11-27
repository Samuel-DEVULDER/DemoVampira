	xref	_WIDTH
	xref	_HEIGHT
	
	xdef _draw_sprite0b
_draw_sprite0b
	move.l	4(sp),a1
	movem.l	d2-d7/a2-a6,-(sp)
	xref	image_data
	lea		image_data,a0

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
	subq.l  #1,D3
.ds_loop1:
	move.l	d7,d0				; src_x = start_x 
	move.l	a3,d1				; src_y = start_y

	move.l  _WIDTH,d2	      ; dest_x
	subq.l	#1,d2

.ds_loop2:
	move.l  D1,D6
	
	swap	d0
	lsr.l	#8,d6
	move.b	d0,d6
	swap	d0
	
	andi.l  #$FFFF,D6

	move.l	(a0,D6.L*4),(a1)+
	
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
