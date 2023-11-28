#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <exec/execbase.h>
#include <exec/memory.h>
#include <exec/exec.h>

#include <graphics/gfxbase.h>
#include <intuition/intuitionbase.h>
#include <cybergraphics/cybergraphics.h>

#include <clib/cybergraphics_protos.h>
#include <clib/dos_protos.h>
#include <clib/exec_protos.h>
#include <clib/intuition_protos.h>
#include <clib/graphics_protos.h>
#include <clib/timer_protos.h>

#ifndef BMF_SPECIALFMT
#define BMF_SPECIALFMT 0x80
#endif

#include <vampire/vampire.h>
#include <proto/vampire.h>
struct Library *VampireBase;

#define DEPTH   32

extern struct ExecBase *SysBase;

struct IntuitionBase    *IntuitionBase;
struct GfxBase          *GfxBase;
struct Library          *CyberGfxBase;
struct timerequest      *timerio;
struct MsgPort          *timerport;
struct Device           *TimerBase;

static struct Screen    *S;
static struct Window    *W;
static struct ColorMap  *CM;
static struct RastPort  *RP;
static struct BitMap    *CybBitMap;
static struct RastPort   CybRasPort;

LONG rowbytes, pixbytes, numrow;
ULONG *bufmem;

LONG WIDTH=320, HEIGHT=180;

extern void prepare(void);

extern void draw_sprite080(ULONG *);
//extern void draw_sprite32b(ULONG *);

extern void draw_sprite16b(ULONG *);
extern void draw_sprite8b_(ULONG *);
extern void draw_sprite8b(ULONG *);
extern void draw_sprite0b(ULONG *);

extern void update_rotate68k(void);
extern void update_rotate080(void);

BYTE convert = 0; // 0=ARGB -1=BGRA 1=RGBA

void error(char *fmt, ...) {
    va_list ap;
    
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(50);
}

void cleanup(void) {
    if(W) {CloseWindow(W);W = NULL;}
    if(S) {CloseScreen(S);S = NULL;}
    if(TimerBase) {CloseDevice((struct IORequest *) timerio);TimerBase = NULL;}
    if(timerio) {DeleteIORequest((struct IORequest *) timerio);timerio = NULL;}
    if(timerport) {DeleteMsgPort(timerport);timerport = NULL;}
    if(CyberGfxBase) {CloseLibrary((void*)CyberGfxBase); CyberGfxBase=NULL;}
    if(GfxBase) {CloseLibrary((void*)GfxBase); GfxBase=NULL;}
    if(IntuitionBase) {CloseLibrary((void*)IntuitionBase); IntuitionBase=NULL;}
}

void openLIBS(void) {
    
    IntuitionBase = (void*)OpenLibrary("intuition.library",0L);
    if(!IntuitionBase) error("No intuition.library!");
     
    GfxBase = (void*)OpenLibrary("graphics.library",0L);
    if(!GfxBase) error("No graphics.library!");
     
    CyberGfxBase = (void*)OpenLibrary("cybergraphics.library",40);
    if(!CyberGfxBase) error("No cybergraphics.library v40 !");
    
    timerport = CreateMsgPort();
    if(!timerport) error("No timerport!");
    timerio = (struct timerequest *)CreateIORequest(timerport, sizeof(struct timerequest));
    if(!timerio) error("Can't create timer io request.");
    if (OpenDevice((STRPTR) TIMERNAME, UNIT_ECLOCK,(struct IORequest *) timerio, 0))
        error("Can't open "TIMERNAME".");
    TimerBase = (void*)timerio->tr_node.io_Device;  
}

double eclock(void)  {
    if(TimerBase) {
        struct EClockVal ecv;
        LONG f = ReadEClock(&ecv);
        static ULONG offset;
        if(f) return (double)((4294967296.0*(LONG)(ecv.ev_hi-(offset?offset:(offset=ecv.ev_hi))) + ecv.ev_lo)/f);
    }
    return 0;
}


WORD PIXMRG16[65536<<PREC];
BYTE PIXMRG8[256<<PREC];
LONG RGB23[65536];

static void precalc() {
    int i, d=(1<<PREC)-1;
    for(i=65536<<PREC; --i>=0;) {
        int mul=i>>16, res;
        res  = ((((i>> 0)&255)*mul+d/2)/d)<<0;
        res |= ((((i>> 8)&255)*mul+d/2)/d)<<8;
        PIXMRG16[i] = res;
    }
    for(i=256<<PREC; --i>=0;) {
        PIXMRG8[i] = ((i&255)*(i>>8)+d/2)/d;
    }
    for(i=65536; --i>=0;) {
        int res;
        res  = ((((i>> 0)&31)*255+16)/31)<<16;
        res |= ((((i>> 5)&63)*255+32)/63)<<24;
        res |= ((((i>>11)&31)*255+16)/31)<<0;
        RGB23[i] = res;
    }
}

#define TIMINGS 50
double timings[TIMINGS];

int main(int ac, char **av)
{
    LONG DispID = INVALID_ID, i=0;
    enum {ARGB,BGRA,RGBA};
    BYTE mc68080 = 0, mc68040 = 0, directdraw = 0, waitTOF = 0, bilinear = 0, ammx = 0, win=0, paused=0, FMT=ARGB;
    BYTE penBLACK, penWHITE;
    int height = 0;
    char *last_fps = NULL;
    struct RastPort *rp = &CybRasPort;
    int XOff=0,YOff=0;
    struct IntuiMessage *msg;
    
    atexit(cleanup);
    openLIBS(); 
    
    /* detect mc68040+ */
    if(SysBase->AttnFlags & AFF_68040) {
        mc68040 = 255;
    }
    
    /* detect Vampire */
    if((SysBase->AttnFlags & (1<<10))) {
        mc68080 = 255;
    }
    
    /* parse cmd line */
    for(i=1; i<ac; ++i) {
        if(!strcmp("-68k", av[i])) {
            mc68080 = 0;
        } else if(!strcmp("-68030", av[i])) {
            mc68040 = mc68080 = 0;
        } else if(!strcmp("-directdraw", av[i])) {
            directdraw = 255;
        } else if(!strcmp("-waitTOF", av[i])) {
            waitTOF = 255;
        } else if(!strcmp("-ammx", av[i])) {
            ammx = 255;
        } else if(!strcmp("-bilinear", av[i])) {
            bilinear = 255;
        } else if(!strcmp("-hires", av[i])) {
            WIDTH = 640;
            HEIGHT = 360;
        } else if(!strcmp("-size", av[i]) && i+2<ac) {
            int w = atoi(av[++i]);
            int h = atoi(av[++i]);
            if(w>0 && h>0) {
                WIDTH = w;
                HEIGHT = h;
            }
        } else if(!strcmp("-win", av[i])) {
            win = 255;
        } else if(!strcmp("-idle", av[i])) {
            SetTaskPri(FindTask(0), -127);
        } else if(!strcmp("-priority", av[i]) && i+1<ac) {
            SetTaskPri(FindTask(0), atoi(av[++i]));
        } else if(!strcmp("?", av[i]) || !strcmp("-h",av[i]) || !strcmp("--help",av[i])) {
            printf("\n");
			printf("Usage: %s [?|-h|--help]\n", av[0]);
            printf("\t[-ammx|-68030] [-bilinear]\n");
            printf("\t[-win|-id 0x<ModeID>] [-hires|-size <width> <height>]\n");
            printf("\t[-directdraw] [-waitTOF]\n");
            printf("\t[-idle|-priority <num>]\n");
            printf("\n");
            printf("Details:\n");
            printf("\n");
            printf("?|-h|--help   : displays this help.\n");
            printf("-ammx         : use ammx instructions to speed up the demo.\n");
            printf("-68030        : select the 030-optimized code. You normally don't need\n");
            printf("                this since the demo will automatically detect your cpu\n");
            printf("                type.\n");
            printf("-bilinear     : activates the bilinear rendering. The images are smoother\n");
            printf("                with this. This is a recommend default option.\n");
            printf("-win          : makes the demo run on a Workbench window.\n");
            printf("-id 0x<Mode>  : makes the demo run on a screen matching the provided\n");
            printf("                mode-id.\n");
            printf("-hires        : displays in 640x360 instead of 320x180.\n");
            printf("-size <w> <h> : uses a <w>x<h> screen or window.\n");
            printf("-directdraw   : directly render on-screen. This increases the FPS a lot,\n");
            printf("                but can provide bad colours if your screen is in PC\n");
            printf("                pixel-format.\n");
            printf("-waitTOF      : waits for VSync before rendering the image. This prevents\n");
            printf("                the tearing effect, but slows the demo to a divisor of the\n");
            printf("                VBL frequency.\n");
            printf("-idle         : makes the demo run with -127 as a priority (very low\n");
            printf("                priority).\n");
            printf("-priority <n> : sets the priority of the demo (0 is normal task).\n");
            printf("\n");
            printf("Typical use:\n");
            printf("\n");
            printf("    CLI> %s -bilinear -win -ammx\n", av[0]);
            printf("\n");
            printf("Compiled on " __DATE__ " " __TIME__ ".\n");
            exit(0);
        } else if(!strcmp("-id", av[i]) && i+1<ac) {
            LONG t = 0, base=10;
            char *s = av[++i];
            if(s[0]=='0' && s[1]=='x') {base=16; s+=2;}
            while(*s) {
                t *= base;
                if(*s>='0' && *s<='9') t+=*s-'0';
                else if(base==16 && *s>='a' && *s<='f') t+=*s-'a'+10;
                else if(base==16 && *s>='A' && *s<='F') t+=*s-'A'+10;
                else error("Invalid id: %s", av[i+1]);
            }
            if(t) DispID = t;
        } else {
            error("Invalid argument: \"%s\"", av[i]);
        }
    }
    if((SysBase->AttnFlags & (1<<10))) {
        printf("Running on 68080, good!\n");
    } else {
        printf("Running on plain 68k, too bad: no AMMX speedup available!\n");
    }
    if(ammx && mc68080) {
        VampireBase = OpenResource( V_VAMPIRENAME );
        if ( !VampireBase ||  
             VampireBase->lib_Version < 45 ||
             V_EnableAMMX( V_AMMX_V2 ) == VRES_ERROR ) {
            printf("Bad core version. Disabling AMMX.\n");
            ammx = 0;
        }
    }
    if(!mc68080 && ammx) {
        printf("Not running on 68080. No AMMX optimization available :(\n");
        ammx=0;
    }
    if(ammx) {
        printf("AMMX speed-up activated.\n");
    } 

    precalc();
    
    /* public screen */
    if(win) {
        struct Screen *S = LockPubScreen(NULL);
        if(S) {
            /* check it is truecolor screen */
            if(IsCyberModeID(GetVPModeID(&S->ViewPort)) &&
                GetCyberMapAttr(S->RastPort.BitMap,(LONG)CYBRMATTR_BPPIX)>=2)   {
                W = OpenWindowTags(NULL,
                   WA_Title,        (ULONG)"demovampira",
                   WA_AutoAdjust,   TRUE,
                   WA_InnerWidth,   WIDTH,
                   WA_InnerHeight,  HEIGHT,
                   WA_MinWidth,     160+20,
                   WA_MinHeight,    100,
                   WA_MaxWidth,     -1,
                   WA_MaxHeight,    -1,             
                   WA_PubScreen,    (ULONG)S,
                   WA_IDCMP,      
                        IDCMP_VANILLAKEY|
                        IDCMP_CLOSEWINDOW|
                        IDCMP_NEWSIZE|
                        0,
                   WA_Flags,        
                        WFLG_DRAGBAR|
                        WFLG_DEPTHGADGET|
                        WFLG_SIZEGADGET|
                        WFLG_ACTIVATE|
                        WFLG_CLOSEGADGET|
                        WFLG_NOCAREREFRESH|
                        0,
                   TAG_DONE);
                if(W) {
                    directdraw = 0;
                    RP = W->RPort;
                    CM = S->ViewPort.ColorMap;      
                    XOff = W->BorderLeft;
                    YOff = W->BorderTop;
                }
            } else {
                printf("Invalid WB mode: 16 or 24bpp required!\n");
            }

            UnlockPubScreen(NULL, S);
        }
    }

    /* custom screen */
    if(!W) {
        if(DispID==INVALID_ID)
        DispID = BestCModeIDTags(CYBRBIDTG_NominalWidth,WIDTH,
                                 CYBRBIDTG_NominalHeight,height=HEIGHT,
                                 CYBRBIDTG_Depth,DEPTH,
                                 TAG_DONE);
        if(DispID==INVALID_ID) // try 4:3
        DispID = BestCModeIDTags(CYBRBIDTG_NominalWidth,WIDTH,
                                 CYBRBIDTG_NominalHeight,height=(int)WIDTH*3/4,
                                 CYBRBIDTG_Depth,DEPTH,
                                 TAG_DONE);
            
        if(DispID==INVALID_ID) 
                error("Cannot find %dx%dx%d screenmode!", WIDTH,HEIGHT,DEPTH);
        if((i=GetCyberIDAttr(CYBRIDATTR_WIDTH,DispID))!=WIDTH) 
                error("bad width (%d)",i);
        if((i=GetCyberIDAttr(CYBRIDATTR_HEIGHT,DispID))<HEIGHT) 
                error("bad height (%d)",i);
        printf("Using -id 0x%x (%dx%dx%d)\n", DispID, 
            GetCyberIDAttr(CYBRIDATTR_WIDTH,DispID),
            GetCyberIDAttr(CYBRIDATTR_HEIGHT,DispID),
            GetCyberIDAttr(CYBRIDATTR_DEPTH,DispID));
        
        S = OpenScreenTags(NULL,
                            SA_Quiet, TRUE,
                            SA_Width, WIDTH,
                            SA_Height, height,
                            SA_Depth, DEPTH,
                            SA_DisplayID, DispID,
                            TAG_DONE);
        if(!S) error("OpenScreenTags");
        
        CM = S->ViewPort.ColorMap;
        RP = &S->RastPort;
        W = OpenWindowTags(NULL,
                           WA_Width,        S->Width,
                           WA_Height,       S->Height,
                           WA_CustomScreen, (ULONG)S,
                           WA_IDCMP,        IDCMP_VANILLAKEY|
                                            0,
                           WA_Flags,        WFLG_NOCAREREFRESH|
                                            WFLG_BACKDROP|
                                            WFLG_BORDERLESS|
                                            0,
                           WA_BackFill,     (ULONG)LAYERS_NOBACKFILL,
                           TAG_DONE);
        if(!W) error("OpenWindowTags");
        
        /* check PC order */
	convert = 0;
	if(directdraw) switch(i=GetCyberMapAttr(RP->BitMap,CYBRMATTR_PIXFMT)) {
        	case PIXFMT_ARGB32: break;
		case PIXFMT_BGRA32: convert=-1; break;
		case PIXFMT_RGBA32: convert=+1; break;
		default: printf("Invalid pixel format, disably -directdraw\n"); break;
	}

    }
    
    /* allocate bitmap */
    if(!directdraw) {
        CybBitMap = (void*)AllocBitMap(WIDTH, HEIGHT,DEPTH,
                    (PIXFMT_ARGB32<<24)|BMF_SPECIALFMT|BMF_MINPLANES,RP->BitMap);
        if(!CybBitMap) error("Can't allocate CybBitMap.");
        /* create rasport */
        InitRastPort(rp = &CybRasPort);
        CybRasPort.BitMap = CybBitMap;
    } else {
        rp = RP;
    }
    
    /* colors */
    SetBPen(RP, penBLACK=ObtainBestPen(CM,
            0x00000000,0x00000000,0x00000000,     
            OBP_Precision,PRECISION_GUI, OBP_FailIfBad,FALSE,
            TAG_DONE)); 
    SetAPen(RP, penWHITE=ObtainBestPen(CM,
            0xffffffff,0xffffffff,0xffffffff,     
            OBP_Precision,PRECISION_GUI, OBP_FailIfBad,FALSE,
            TAG_DONE));
    SetDrMd(RP, JAM2);
    // rowbytes =  GetCyberMapAttr(CybBitMap,CYBRMATTR_XMOD);
    // pixbytes =  GetCyberMapAttr(CybBitMap,CYBRMATTR_BPPIX);
    // bufmem = (UWORD*)GetCyberMapAttr(CybBitMap,CYBRMATTR_DISPADR);
    
    prepare();
    while(1) {
        LONG sigs = SetSignal(0L,0L);

        do {
            APTR handle = LockBitMapTags(rp->BitMap,
                LBMI_BASEADDRESS, &bufmem,
                LBMI_BYTESPERROW, &rowbytes,
                TAG_DONE);
            if(handle) {
                if(directdraw && waitTOF) WaitTOF();
                if(bilinear) {
                    if(ammx) {
                        draw_sprite080(bufmem);
                    } else if(mc68040 || mc68080) {
                        if(convert) draw_sprite8b_(bufmem); 
						else        draw_sprite8b(bufmem);
                    } else {
                        draw_sprite16b(bufmem);
                    }
                } else {
                    draw_sprite0b(bufmem);
                }
                UnLockBitMap(handle);               
            }
        } while(0);
        if(!directdraw) {
            if(waitTOF) WaitTOF();
            /* make it visible */
            BltBitMapRastPort(rp->BitMap,
                0, 0,
                RP,
                XOff,YOff,WIDTH,HEIGHT,
                0xc0);          
        }
        /* compute time */
        do {
            static int i=0;
            double t = eclock();
            double s = timings[i];
            timings[i++] = t; if(i==TIMINGS) i=0;
            Move(RP, XOff+4, YOff+HEIGHT-10);
            if(s) {
                static char buf[20];
                long f = 1000*TIMINGS/(t-s);
                sprintf(buf,"FPS: %ld.%03ld", f/1000, f%1000);
                // doesn't change anything ==> SetAPen(&CybRasPort, 15);
                Text(RP, last_fps=buf, strlen(buf));
            } else {
                char *s="FPS: computing...";
                Text(RP, s, strlen(s));
                last_fps = NULL;
            }       
        } while(0);

        
        if(ammx && bilinear)
            update_rotate080();
        else
            update_rotate68k();
        
        do {
            while((msg=(struct IntuiMessage*)GetMsg(W->UserPort))) {
                int class,code; char vanilla=0;

                class = msg->Class;
                code  = msg->Code;
                ReplyMsg((struct Message*)msg);

                switch(class) {
                case IDCMP_NEWSIZE:
                    if(!directdraw) {
                        FreeBitMap(CybBitMap);
                        WIDTH  = W->Width - W->BorderRight - W->BorderLeft;
                        HEIGHT = W->Height - W->BorderTop - W->BorderBottom;
                        CybBitMap = (void*)AllocBitMap(WIDTH, HEIGHT,DEPTH,
                            (PIXFMT_ARGB32<<24)|BMF_SPECIALFMT|BMF_MINPLANES,RP->BitMap);
                        if(!CybBitMap) error("Can't allocate CybBitMap.");
                        InitRastPort(rp = &CybRasPort);
                        CybRasPort.BitMap = CybBitMap;
                    }
                    break;

                case IDCMP_REFRESHWINDOW:
                    BeginRefresh(W);
                    EndRefresh(W, TRUE);
                    break;

                case IDCMP_CLOSEWINDOW:
                    sigs |= SIGBREAKF_CTRL_C;
                    break;
                
                case IDCMP_VANILLAKEY: 
                    if(code==3 || code==27) {sigs |= SIGBREAKF_CTRL_C;paused=0;}
                    if(code==4) paused = ~paused;
                    break;
                
                /*
                case IDCMP_RAWKEY: {
                    int kc       = code&127;
                    int released = (code&128)?1:0;
                    if(kc==0x45 && released) 
                    break;
                }
                */
                }
            }
            if(paused) {
                for(i=TIMINGS; --i>=0;) timings[i]=0;
                sigs = Wait(SIGBREAKF_CTRL_D|SIGBREAKF_CTRL_C|1<<W->UserPort->mp_SigBit);
                if(sigs & SIGBREAKF_CTRL_C) paused = 0;
            }
        } while(paused);
        
        //Delay(1);
        if(sigs & SIGBREAKF_CTRL_C) break;
        if(sigs & SIGBREAKF_CTRL_D) {
            int i;
            SetSignal(0,SIGBREAKF_CTRL_D);
            sigs = Wait(SIGBREAKF_CTRL_D|SIGBREAKF_CTRL_C);
            if(sigs & SIGBREAKF_CTRL_C) break;
            for(i=TIMINGS; --i>=0;) timings[i]=0;
        }
    }
    ReleasePen(CM, penBLACK);
    ReleasePen(CM, penWHITE);
    if(!directdraw) FreeBitMap(CybBitMap);

    SetSignal(0,SIGBREAKF_CTRL_C);
    if(last_fps) printf("%s\n", last_fps);
    
    
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