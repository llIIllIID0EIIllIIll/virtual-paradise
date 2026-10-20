# Plymouth theme

`virtual-paradise.script` is the boot and shutdown animation, installed by
`lib/plymouth.sh` as its own theme:

    /usr/share/plymouth/themes/virtual-paradise/
    /etc/plymouth/plymouthd.conf   (Theme=virtual-paradise)

`install.sh` used to copy the script over
`/usr/share/plymouth/themes/omarchy/omarchy.script` and to generate ~330 PNG
frames inside that same package-owned directory. A package update silently
reverted the animation, and `uninstall.sh` had no way to put the stock splash
back. The theme now ships complete and self-contained, and the distro theme is
left alone.

The animation frames are encoded from `backgrounds/Miku_animated_full.mp4`
(259 frames) and `backgrounds/Miku_missing.mp4` (72 frames) with ffmpeg during
the install. The lock, entry, bullet and progress-bar images come from
Omarchy's own Plymouth theme (`omarchy-settings`, MIT licensed) and are
copied into the theme directory, so the splash does not depend on that
directory at runtime.

The frames are 1600×900 with a 256 colour palette, which is the same picture
once Plymouth stretches it over the screen (Plymouth converts palette PNGs
through `png_set_palette_to_rgb`) and about a third of the image data. The
picture is centred on the screen; the bars around it are filled with a dark
violet gradient, `frame.png` draws a neon border with corner brackets around
the picture, and `tile.png` is tiled through the bars as a cyber pattern.
