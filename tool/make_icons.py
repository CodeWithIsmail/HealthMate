"""Generate launcher-icon source assets from the 512px logo.

Two outputs, because Android adaptive icons and legacy/iOS icons need
different padding:

  app_icon.png            1024, white background, artwork at 80% height.
                          Used for legacy Android mipmaps and iOS, where the
                          launcher applies only a rounded-corner mask.
  app_icon_foreground.png 1024, transparent, artwork at 73% height.
                          Android adaptive icons only ever show the central
                          66% of the canvas. flutter_launcher_icons already
                          wraps this drawable in `android:inset="16%"`, so it
                          renders at 68% of the canvas and this file must NOT
                          pre-apply the safe-zone padding a second time --
                          doing so leaves the artwork visibly undersized.
                          0.73 x 0.68 puts the artwork at ~50% of the canvas:
                          its diagonal is then ~64%, just inside the 66.7%
                          circle that a round mask cuts.
"""

from PIL import Image

SRC = "/home/ismail360/Desktop/SPM/appLogo.png"
OUT = "/home/ismail360/Desktop/SPM/HealthMate/assets/icon"
CANVAS = 1024


def render(target_fraction: float, background, path: str) -> None:
    logo = Image.open(SRC).convert("RGBA")
    logo = logo.crop(logo.split()[3].getbbox())  # trim transparent margin

    target = int(CANVAS * target_fraction)
    scale = target / max(logo.width, logo.height)
    logo = logo.resize(
        (max(1, round(logo.width * scale)), max(1, round(logo.height * scale))),
        Image.LANCZOS,
    )

    canvas = Image.new("RGBA", (CANVAS, CANVAS), background)
    canvas.alpha_composite(logo, ((CANVAS - logo.width) // 2, (CANVAS - logo.height) // 2))
    canvas.save(path)
    print(f"{path}  artwork {logo.width}x{logo.height} on {CANVAS}x{CANVAS}")


render(0.80, (255, 255, 255, 255), f"{OUT}/app_icon.png")
render(0.73, (0, 0, 0, 0), f"{OUT}/app_icon_foreground.png")
