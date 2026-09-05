import AppKit

let target = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
for (name, size) in [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32), ("icon_32x32@2x",64),
                     ("icon_128x128",128), ("icon_128x128@2x",256), ("icon_256x256",256), ("icon_256x256@2x",512),
                     ("icon_512x512",512), ("icon_512x512@2x",1024)] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 58, y: 58, width: 908, height: 908), xRadius: 212, yRadius: 212)
    NSColor(calibratedRed: 0.06, green: 0.13, blue: 0.12, alpha: 1).setFill()
    tile.fill()
    let green = NSColor(calibratedRed: 0.36, green: 0.85, blue: 0.69, alpha: 1)
    green.setStroke()
    let arc = NSBezierPath()
    arc.lineWidth = 57
    arc.lineCapStyle = .round
    arc.move(to: NSPoint(x: 280, y: 395))
    arc.line(to: NSPoint(x: 280, y: 510))
    arc.curve(to: NSPoint(x: 744, y: 510), controlPoint1: NSPoint(x: 280, y: 825), controlPoint2: NSPoint(x: 744, y: 825))
    arc.line(to: NSPoint(x: 744, y: 395))
    arc.stroke()
    green.setFill()
    for x in [CGFloat(243), CGFloat(677)] {
        NSBezierPath(roundedRect: NSRect(x: x, y: 290, width: 104, height: 205), xRadius: 48, yRadius: 48).fill()
    }
    for (x, height) in [(438,100),(496,205),(554,140)] {
        NSBezierPath(roundedRect: NSRect(x: x, y: 395 - height / 2, width: 30, height: height), xRadius: 15, yRadius: 15).fill()
    }
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(target)/\(name).png"))
}
