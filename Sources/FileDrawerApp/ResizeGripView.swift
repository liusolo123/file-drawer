import AppKit

/// 面板右下角的缩放把手：向下拖增高，向右拖增宽。
final class ResizeGripView: NSView {
    var onDrag: ((_ deltaWidth: CGFloat, _ deltaHeight: CGFloat) -> Void)?

    private var lastPoint = NSPoint.zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        lastPoint = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        onDrag?(current.x - lastPoint.x, lastPoint.y - current.y)
        lastPoint = current
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.tertiaryLabelColor.setStroke()

        let path = NSBezierPath()
        path.lineWidth = 1.2

        for offset in stride(from: CGFloat(4), through: 12, by: 4) {
            path.move(to: NSPoint(x: bounds.maxX - offset, y: bounds.minY + 3))
            path.line(to: NSPoint(x: bounds.maxX - 3, y: bounds.minY + offset))
        }

        path.stroke()
    }
}
