import AppKit

guard CommandLine.arguments.count == 3 else {
    let usage = "usage: swift Design/make-appicon.swift <source.png> <output.iconset>\n"
    FileHandle.standardError.write(Data(usage.utf8))
    exit(2)
}

let source = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]

guard let input = NSImage(contentsOfFile: source),
      let tiff = input.tiffRepresentation,
      let inputRep = NSBitmapImageRep(data: tiff)
else {
    FileHandle.standardError.write(Data("cannot read the source image\n".utf8))
    exit(1)
}

let width = inputRep.pixelsWide
let height = inputRep.pixelsHigh

func opaque(_ x: Int, _ y: Int) -> Bool {
    (inputRep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05
}

func bounds(_ probe: (Int) -> Bool, upTo limit: Int) -> (first: Int, last: Int)? {
    var first: Int?
    var last: Int?
    for index in 0 ..< limit where probe(index) {
        if first == nil {
            first = index
        }
        last = index
    }
    guard let first, let last else { return nil }
    return (first, last)
}

func span(vertical: Bool) -> (first: Int, last: Int)? {
    let across = vertical ? width : height
    let along = vertical ? height : width
    var first = along
    var last = -1

    for step in 1 ..< 8 {
        let line = across * step / 8
        let found = bounds({ index in
            vertical ? opaque(line, index) : opaque(index, line)
        }, upTo: along)
        guard let found else { continue }
        first = min(first, found.first)
        last = max(last, found.last)
    }
    return last < 0 ? nil : (first, last)
}

guard let horizontal = span(vertical: false),
      let vertical = span(vertical: true)
else {
    FileHandle.standardError.write(Data("found no opaque area\n".utf8))
    exit(1)
}

let side = max(horizontal.last - horizontal.first + 1, vertical.last - vertical.first + 1)
let originX = horizontal.first - (side - (horizontal.last - horizontal.first + 1)) / 2
let originY = vertical.first - (side - (vertical.last - vertical.first + 1)) / 2

print("source \(width)×\(height), artwork \(side)×\(side) at (\(originX), \(originY))")

func render(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: px, height: px)

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let canvas = CGFloat(px)
    let plate = canvas
    let inset: CGFloat = 0

    input.draw(
        in: NSRect(x: inset, y: inset, width: plate, height: plate),
        from: NSRect(x: originX, y: height - originY - side, width: side, height: side),
        operation: .sourceOver,
        fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

let plan: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

let master = "\(outDir)/../AppIcon-1024.png"
guard let data = render(1024) else {
    FileHandle.standardError.write(Data("failed to render the master\n".utf8))
    exit(1)
}

try data.write(to: URL(fileURLWithPath: master))

// sips does the resizing: macOS 26 treats PNGs drawn through our own
// NSBitmapImageRep as a legacy icon and puts a light plate behind it.
for (name, px) in plan {
    let sips = Process()
    sips.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    sips.arguments = ["-z", "\(px)", "\(px)", master, "--out", "\(outDir)/\(name).png"]
    sips.standardOutput = FileHandle.nullDevice
    sips.standardError = FileHandle.nullDevice
    try sips.run()
    sips.waitUntilExit()
    guard sips.terminationStatus == 0 else {
        FileHandle.standardError.write(Data("failed to resize: \(name)\n".utf8))
        exit(1)
    }
}

print("rendered \(plan.count) sizes")
