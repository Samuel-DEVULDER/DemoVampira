#include <stdio.h>
#include <stdlib.h>

#include <exec/execbase.h>
#include <exec/memory.h>
#include <exec/exec.h>

#include <intuition/intuitionbase.h>
#include <cybergraphics/cybergraphics.h>

#include <clib/cybergraphics_protos.h>
#include <clib/dos_protos.h>
#include <clib/exec_protos.h>
#include <clib/intuition_protos.h>

extern struct ExecBase *SysBase;

struct IntuitionBase    *IntuitionBase;
struct GfxBase          *GfxBase;
struct Library          *CyberGfxBase;
struct Library          *KeymapBase;
struct Library          *AslBase;

static struct Screen    *S;

LONG rowbytes, pixbytes;
UWORD *bufmem;

extern void prepare();
extern void draw_sprite(UWORD *);
extern void update_rotate();

 static short ColorModel[] = {PIXFMT_RGB16,-1};
 static struct TagItem CyberModeTags[] = {
    CYBRMREQ_CModelArray,(ULONG)ColorModel,
    CYBRMREQ_MinWidth,640,
    CYBRMREQ_MinHeight,480,
    TAG_DONE,0
  };

void cleanup(void) {
	if(S) {CloseScreen(S);S=NULL;}
	if(CyberGfxBase) {CloseLibrary((void*)CyberGfxBase); CyberGfxBase=NULL;}
	if(GfxBase) {CloseLibrary((void*)GfxBase); GfxBase=NULL;}
	if(IntuitionBase) {CloseLibrary((void*)IntuitionBase); IntuitionBase=NULL;}
}

void error(char *fmt, ...) {
	va_list ap;
    
    va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
	va_end(ap);
	exit(50);
}

BYTE RGB16PC;

#define PREC 5
WORD PIXMRG[65536<<PREC];

void preparePIXMRG() {
	int i;
	for(i=65536<<PREC; --i>=0;) {
		int mul=i>>16, res;
		res  = ((((i>> 0)&31)*mul)>>PREC)<<0;
		res += ((((i>> 5)&63)*mul)>>PREC)<<5;
		res += ((((i>>11)&31)*mul)>>PREC)<<11;
		PIXMRG[i] = res;
	}
}

int main(int ac, char **av)
{
	LONG DispID = -1, i=0;
	
	preparePIXMRG();
	
	atexit(cleanup);
	
	IntuitionBase = (void*)OpenLibrary("intuition.library",0L);
	if(!IntuitionBase) error("No intuition.library!");
	 
	GfxBase = (void*)OpenLibrary("graphics.library",0L);
	if(!GfxBase) error("No graphics.library!");
	 
	CyberGfxBase = (void*)OpenLibrary("cybergraphics.library",40);
	if(!CyberGfxBase) error("No cybergraphics.library v40 !");
	
	DispID = BestCModeIDTags(CYBRBIDTG_NominalWidth,640,
                             CYBRBIDTG_NominalHeight,360,
                             CYBRBIDTG_Depth,16,
                             TAG_DONE);
	if(DispID==INVALID_ID) error("Cannot find 640x360x16 screenmode!");
	if((i=GetCyberIDAttr(CYBRIDATTR_WIDTH,DispID))!=640) error("bad width (¨%d)",i);
	if((i=GetCyberIDAttr(CYBRIDATTR_HEIGHT,DispID))<360) error("bad height (%d)",i);
	
	S = OpenScreenTags(NULL,
						SA_Quiet, TRUE,
						SA_Width, 640,
						SA_Height, 360,
						SA_Depth, 16,
						SA_DisplayID, DispID,
						TAG_DONE);
	if(!S) error("OpenScreenTags");
	rowbytes =  GetCyberMapAttr(S->RastPort.BitMap,CYBRMATTR_XMOD);
	pixbytes =  GetCyberMapAttr(S->RastPort.BitMap,CYBRMATTR_BPPIX);
	bufmem = (UWORD*)GetCyberMapAttr(S->RastPort.BitMap,CYBRMATTR_DISPADR);
	switch(i=GetCyberMapAttr(S->RastPort.BitMap,CYBRMATTR_PIXFMT)) {
		case PIXFMT_RGB16: RGB16PC=0; break;
		case PIXFMT_RGB16PC: RGB16PC=255; break;
		default: error("Bad pixel fmt (%$x)", i); break;
	}
	// do {
		// int i;
		// for(i=0; i<640*480;++i) bufmem[i]=i;
	// } while(0);
	
	// Delay(50*30);
	
	prepare();
	while(1) {
		LONG sigs = SetSignal(0L,0L);
		draw_sprite(bufmem);
		update_rotate();
		//Delay(1);
		if(sigs & SIGBREAKF_CTRL_C) break;
		if(sigs & SIGBREAKF_CTRL_D) {
			SetSignal(0,SIGBREAKF_CTRL_D);
			sigs = Wait(SIGBREAKF_CTRL_D|SIGBREAKF_CTRL_C);
			if(sigs & SIGBREAKF_CTRL_C) break;
		}
	}
	SetSignal(0,SIGBREAKF_CTRL_C);
	
	cleanup();
	return 0;
}

/*
    xdef _update_rotate
_update_rotate
    movem.l d2-d7/a2-a6,-(sp)
    lea    DATA(pc),A6
    bsr update_rotate
    movem.l (sp)+,d2-d7/a2-a6
    rts

    xdef _draw_sprite
_draw_sprite
    move.l 4(sp),a1
    movem.l d2-d7/a2-a6,-(sp)
    lea    image_data+70(pc),a0
    lea    DATA(pc),A6
    bsr draw_sprite2
    movem.l (sp)+,d2-d7/a2-a6
    rts


    xdef _prepare
_prepare:
        lea    image_data+70(pc),a0
    move.l  #256*256,d0
.1
    move.w    (a0),D1
    ror.w    #8,D1
    move.w    D1,(a0)+
    subq.l    #1,D0
    bne    .1

        rts 
*/