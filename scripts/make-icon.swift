import AppKit

let size: CGFloat = 1024
let outputPath = "App/AppIcon-1024.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("无法创建位图")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func rounded(_ rect: NSRect, _ radius: CGFloat, fill: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
}

// 背景圆角方块
let background = NSBezierPath(
    roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912),
    xRadius: 200,
    yRadius: 200
)
let gradient = NSGradient(
    starting: color(0xFBF8F3),
    ending: color(0xE4DACB)
)!
gradient.draw(in: background, angle: -90)

// 极细内描边
color(0xD5C9B8, alpha: 0.9).setStroke()
background.lineWidth = 3
background.stroke()

// 顶部中央的刘海
let notch = NSBezierPath()
notch.move(to: NSPoint(x: 417, y: 968))
notch.line(to: NSPoint(x: 607, y: 968))
notch.line(to: NSPoint(x: 607, y: 938))
notch.curve(
    to: NSPoint(x: 587, y: 918),
    controlPoint1: NSPoint(x: 607, y: 928),
    controlPoint2: NSPoint(x: 598, y: 918)
)
notch.line(to: NSPoint(x: 437, y: 918))
notch.curve(
    to: NSPoint(x: 417, y: 938),
    controlPoint1: NSPoint(x: 426, y: 918),
    controlPoint2: NSPoint(x: 417, y: 928)
)
notch.close()
color(0x23262B).setFill()
notch.fill()

// 抽屉主体
rounded(NSRect(x: 238, y: 300, width: 548, height: 330), 34, fill: color(0x3B4047))
// 抽屉内腔
rounded(NSRect(x: 272, y: 382, width: 480, height: 226), 22, fill: color(0x2A2E33))

// 文件纸
rounded(NSRect(x: 356, y: 610, width: 312, height: 168), 10, fill: color(0xFFFFFF, alpha: 0.96))
rounded(NSRect(x: 386, y: 648, width: 292, height: 150), 10, fill: color(0xFFFFFF, alpha: 0.98))

// 文件夹
rounded(NSRect(x: 326, y: 540, width: 372, height: 196), 18, fill: color(0x5C7FA3))
rounded(NSRect(x: 326, y: 708, width: 152, height: 52), 14, fill: color(0x6E92B6))

// 抽屉前板
rounded(NSRect(x: 238, y: 300, width: 548, height: 92), 34, fill: color(0x474D55))
// 把手
rounded(NSRect(x: 452, y: 336, width: 120, height: 14), 7, fill: color(0x7C848E))

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("无法编码 PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("已生成 \(outputPath)")
