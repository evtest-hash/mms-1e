#!/usr/bin/env python3
"""Generate macOS .icns app icon using Core Graphics via Swift."""
import subprocess, os

ICONSET = "build/AppIcon.iconset"
ICNS_OUT = "Resources/AppIcon.icns"

SIZES = [
    ("icon_16x16.png",        16),
    ("icon_16x16@2x.png",     32),
    ("icon_32x32.png",        32),
    ("icon_32x32@2x.png",     64),
    ("icon_128x128.png",     128),
    ("icon_128x128@2x.png",  256),
    ("icon_256x256.png",     256),
    ("icon_256x256@2x.png",  512),
    ("icon_512x512.png",     512),
    ("icon_512x512@2x.png", 1024),
]


def generate_png(path: str, size: int):
    swift_code = f"""
import Cocoa
let size = {size}
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let s = CGFloat(size)
let inset: CGFloat = s * 0.05
let rect = CGRect(x: inset, y: inset, width: s - inset*2, height: s - inset*2)
let radius: CGFloat = s * 0.22
let bgPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(bgPath)
ctx.setFillColor(red: 0.16, green: 0.47, blue: 1.0, alpha: 1.0)
ctx.fillPath()
let cardW = s * 0.52; let cardH = s * 0.46
let cardX = (s - cardW) / 2; let cardY = s * 0.34
let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)
let cardRadius = s * 0.03
let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
ctx.addPath(cardPath)
ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.95)
ctx.fillPath()
let pinW = s * 0.06; let pinH = s * 0.14
let pins: [CGFloat] = [cardX + cardW * 0.18, cardX + cardW * 0.43, cardX + cardW * 0.65]
for px in pins {{
    ctx.addRect(CGRect(x: px, y: cardY + cardH - pinH - s*0.03, width: pinW, height: pinH))
}}
ctx.setFillColor(red: 0.16, green: 0.47, blue: 1.0, alpha: 1.0)
ctx.fillPath()
let cx = s * 0.5; let ay = s * 0.12; let az = s * 0.15
ctx.move(to: CGPoint(x: cx, y: ay))
ctx.addLine(to: CGPoint(x: cx - az*0.7, y: ay + az*0.7))
ctx.addLine(to: CGPoint(x: cx - az*0.25, y: ay + az*0.7))
ctx.addLine(to: CGPoint(x: cx - az*0.25, y: ay + az*1.3))
ctx.addLine(to: CGPoint(x: cx + az*0.25, y: ay + az*1.3))
ctx.addLine(to: CGPoint(x: cx + az*0.25, y: ay + az*0.7))
ctx.addLine(to: CGPoint(x: cx + az*0.7, y: ay + az*0.7))
ctx.closePath()
ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.9)
ctx.fillPath()
img.unlockFocus()
let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "{path}"))
"""
    subprocess.run(["/usr/bin/swift", "-e", swift_code], check=True,
                   capture_output=True, text=True)


def main():
    os.makedirs(ICONSET, exist_ok=True)
    os.makedirs(os.path.dirname(ICNS_OUT), exist_ok=True)

    for name, size in SIZES:
        out = os.path.join(ICONSET, name)
        print(f"  {name} ({size}x{size})...", end=" ", flush=True)
        generate_png(out, size)
        print("OK")

    print("Creating .icns...")
    subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", ICNS_OUT], check=True)
    print(f"Done: {ICNS_OUT}")


if __name__ == "__main__":
    main()
