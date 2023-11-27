Hello,
                                ^8^

This is a little demo that Santa left in my chimney for all amigas
capable of displaying true colour images (16/24/32 bits.)

By default, the demo runs on its own screen in 320x180x24bpp graphics
mode without bilinear interpolation of pixels. Since this is fast but
displays an ugly texture, you can add "-bilinear" on the command-line
to enable the bilinear rendering. With this option, the quality is much
improved! But yet it is quite slow.

You can make it run faster by writing directly on screen with the
"-directdraw" command-line option. But, if you are lucky-enough to have
a 68080, you can add "-ammx" to get access to the full power of the 080.
Using AMMX the bilinear will be very nice and smooth.

Oh you may think that 320x180 is too small a screen. You are right. Then
try with the "-hires" option. It'll use 640x360 a screen. The fps will
probably be 4 times smaller then. If the 16:9 aspect ratio doesn't suit
your monitor, you can use "-size <width> <height>" to specify the exact
screen-size you want. You can even use "-modeid 0x<hexa>" to specify the
very precise screen mode to use. Just be sure to choose a 32bpp modeid.

The demo runs in full multitasking. You can go back of forth on the WB
using AMIGA-M key. You can launch it with a low priority by adding "-idle"
on the command-line or set a specific priority with the "-priority <pri>"
option. This makes a perfect screen-saver!

If your WB is truecolor (16bpp at least), you can make the demo run in
a window on your workbench by using the command-line argument "-win". You
can then move or resize the window as you wish. The smaller the window is,
the higher the frame rate rises. Notice: if the WB isn't capable of
displaying the demo, it'll revert to the full-screen mode, so it is safe
to always add the "-win" option.

Typical suggested command line is:
    demovampira.xmas -bilinear -ammx -win 

You can quit the demo at any time by pressing CTRL-C or ESC. CTRL-D will
pause the display for you to see the details of the picture. On still
image you'll see how "-bilinear" gives much nicer and smooth pictures
than without it.

Merry Christmas,
    and a happy new Year!
                                ^8^
__sam__
___________________________________________________________________________
PS: Here is the full list of the command-line options. None is mandatory.
By default the demo will adapt to your configuration:

Usage: demovampira [?|-h|--help]
        [-ammx|-68030] [-bilinear]
        [-win|-id 0x<ModeID>] [-hires|-size <width> <height>]
        [-directdraw] [-waitTOF]
        [-idle|-priority <num>]

Details:

?|-h|--help   : displays this help.
-ammx         : use ammx instructions to speed up the demo.
-68030        : select the 030-optimized code. You normally don't need
                this since the demo will automatically detect your cpu
                type.
-bilinear     : activates the bilinear rendering. The images are smoother
                with this. This is a recommend default option.
-win          : makes the demo run on a Workbench window.
-id 0x<Mode>  : makes the demo run on a screen matching the provided
                mode-id.
-hires        : displays in 640x360 instead of 320x180.
-size <w> <h> : uses a <w>x<h> screen or window.
-directdraw   : directly render on-screen. This increases the FPS a lot,
                but can provide bad colours if your screen is in PC
                pixel-format.
-waitTOF      : waits for VSync before rendering the image. This prevents
                the tearing effect, but slows the demo to a divisor of the
                VBL frequency.
-idle         : makes the demo run with -127 as a priority (very low
                priority).
-priority <n> : sets the priority of the demo (0 is normal task).

Typical use:

    CLI> demovampira -bilinear -win -ammx

Compiled on Dec 25 2017 21:21:00.
