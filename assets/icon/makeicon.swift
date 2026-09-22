import Cocoa

// 닦아(ddak-a) 앱 아이콘 시안 생성기 — 2026-09-22
// 앱 오버레이 색과 동일 계열로 맞춘다: 하늘색 #87CEEB (0.53, 0.81, 0.92)

let sky      = NSColor(calibratedRed: 0.53, green: 0.81, blue: 0.92, alpha: 1.0)
let skyDeep  = NSColor(calibratedRed: 0.29, green: 0.63, blue: 0.82, alpha: 1.0)
let inkBlue  = NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.50, alpha: 1.0)
let paper    = NSColor(calibratedRed: 0.98, green: 0.99, blue: 1.00, alpha: 1.0)

func squircle(_ rect: NSRect) -> NSBezierPath {
    // macOS Big Sur 이후 아이콘 모서리 비율(약 22.5%)에 맞춘 근사
    return NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.height * 0.225)
}

/// 4갈래 반짝임 — 꼭짓점 사이를 중심 쪽으로 오목하게 당겨 별처럼 만든다
func sparkle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    let k = r * 0.12 // 허리가 얼마나 잘록한지
    let pts = [(CGFloat(0), r), (r, CGFloat(0)), (CGFloat(0), -r), (-r, CGFloat(0))]
    p.move(to: NSPoint(x: cx + pts[0].0, y: cy + pts[0].1))
    for i in 0..<4 {
        let a = pts[i], b = pts[(i + 1) % 4]
        let c1 = NSPoint(x: cx + a.0 * 0.18 + b.0 * k / r, y: cy + a.1 * 0.18 + b.1 * k / r)
        let c2 = NSPoint(x: cx + b.0 * 0.18 + a.0 * k / r, y: cy + b.1 * 0.18 + a.1 * k / r)
        p.curve(to: NSPoint(x: cx + b.0, y: cy + b.1), controlPoint1: c1, controlPoint2: c2)
    }
    p.close()
    return p
}

/// 키보드 — 몸체 + 키 그리드 + 스페이스바
func drawKeyboard(in box: NSRect, body: NSColor, keys: NSColor) {
    let bodyPath = NSBezierPath(roundedRect: box, xRadius: box.height * 0.13, yRadius: box.height * 0.13)
    body.setFill()
    bodyPath.fill()

    let cols = 6, rows = 3
    let pad = box.width * 0.075
    let inner = NSRect(x: box.minX + pad, y: box.minY + pad,
                       width: box.width - pad * 2, height: box.height - pad * 2)
    let gap = inner.width * 0.028
    let keyW = (inner.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
    // 맨 아랫줄은 스페이스바 한 칸이 차지한다
    let keyH = (inner.height - gap * CGFloat(rows)) / CGFloat(rows + 1)

    keys.setFill()
    for r in 0..<rows {
        for c in 0..<cols {
            let x = inner.minX + (keyW + gap) * CGFloat(c)
            let y = inner.maxY - keyH - (keyH + gap) * CGFloat(r)
            let kr = NSRect(x: x, y: y, width: keyW, height: keyH)
            NSBezierPath(roundedRect: kr, xRadius: keyW * 0.22, yRadius: keyW * 0.22).fill()
        }
    }
    let sbW = inner.width * 0.58
    let sb = NSRect(x: inner.midX - sbW / 2, y: inner.minY, width: sbW, height: keyH)
    NSBezierPath(roundedRect: sb, xRadius: keyH * 0.32, yRadius: keyH * 0.32).fill()
}

func render(variant: Int, side: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 아이콘 본체는 캔버스의 82% — macOS 아이콘 표준 여백
    let m = side * 0.09
    let plate = NSRect(x: m, y: m, width: side - m * 2, height: side - m * 2)
    let shape = squircle(plate)

    switch variant {
    case 1, 3:
        NSGradient(starting: sky, ending: skyDeep)!.draw(in: shape, angle: -90)
    default:
        NSGradient(starting: paper, ending: NSColor(calibratedWhite: 0.90, alpha: 1.0))!.draw(in: shape, angle: -90)
    }

    // 위쪽 유리 하이라이트 — 평평해 보이지 않게
    NSGraphicsContext.current?.saveGraphicsState()
    shape.setClip()
    NSColor(calibratedWhite: 1.0, alpha: variant == 2 ? 0.55 : 0.22).setFill()
    NSBezierPath(ovalIn: NSRect(x: plate.minX - plate.width * 0.25, y: plate.midY,
                                width: plate.width * 1.5, height: plate.height * 0.95)).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let kbW = plate.width * 0.66
    let kbBox = NSRect(x: plate.midX - kbW / 2, y: plate.midY - kbW * 0.30 - plate.height * 0.02,
                       width: kbW, height: kbW * 0.60)

    switch variant {
    case 1:
        drawKeyboard(in: kbBox, body: paper, keys: sky)
        NSColor.white.setFill()
        sparkle(cx: plate.midX + kbW * 0.46, cy: plate.midY + kbW * 0.40, r: plate.width * 0.105).fill()
        sparkle(cx: plate.midX - kbW * 0.44, cy: plate.midY + kbW * 0.26, r: plate.width * 0.062).fill()
        sparkle(cx: plate.midX + kbW * 0.20, cy: plate.midY + kbW * 0.50, r: plate.width * 0.040).fill()
    case 2:
        drawKeyboard(in: kbBox, body: skyDeep, keys: paper)
        inkBlue.setFill()
        sparkle(cx: plate.midX + kbW * 0.46, cy: plate.midY + kbW * 0.40, r: plate.width * 0.105).fill()
        sparkle(cx: plate.midX - kbW * 0.44, cy: plate.midY + kbW * 0.26, r: plate.width * 0.062).fill()
        sparkle(cx: plate.midX + kbW * 0.20, cy: plate.midY + kbW * 0.50, r: plate.width * 0.040).fill()
    default:
        // 닦고 지나간 궤적을 대각선 띠로 표현
        drawKeyboard(in: kbBox, body: paper, keys: sky)
        NSGraphicsContext.current?.saveGraphicsState()
        shape.setClip()
        let swipe = NSBezierPath()
        swipe.move(to: NSPoint(x: plate.minX - plate.width * 0.1, y: plate.minY + plate.height * 0.26))
        swipe.curve(to: NSPoint(x: plate.maxX + plate.width * 0.1, y: plate.minY + plate.height * 0.78),
                    controlPoint1: NSPoint(x: plate.midX - plate.width * 0.1, y: plate.minY + plate.height * 0.80),
                    controlPoint2: NSPoint(x: plate.midX + plate.width * 0.1, y: plate.minY + plate.height * 0.22))
        swipe.lineWidth = plate.width * 0.17
        swipe.lineCapStyle = .round
        NSColor(calibratedWhite: 1.0, alpha: 0.48).setStroke()
        swipe.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()
        NSColor.white.setFill()
        sparkle(cx: plate.midX + kbW * 0.46, cy: plate.midY + kbW * 0.42, r: plate.width * 0.095).fill()
        sparkle(cx: plate.midX - kbW * 0.46, cy: plate.midY + kbW * 0.22, r: plate.width * 0.055).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments[1]
for v in 1...3 {
    save(render(variant: v, side: 1024), "\(outDir)/variant\(v)-1024.png")
    save(render(variant: v, side: 128), "\(outDir)/variant\(v)-128.png")
}

// 세 시안을 한 장에 나란히 — 큰 크기와 실제 Dock 크기를 같이 본다
let sheetW: CGFloat = 1200, sheetH: CGFloat = 560
let sheet = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(sheetW), pixelsHigh: Int(sheetH),
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheet)
NSColor(calibratedWhite: 0.16, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 26, weight: .semibold),
    .foregroundColor: NSColor.white
]
let smallAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 17, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.72, alpha: 1.0)
]
let names = ["A · 하늘색 바탕", "B · 밝은 바탕", "C · 닦임 궤적"]
for v in 1...3 {
    let big = NSImage(size: NSSize(width: 320, height: 320))
    big.addRepresentation(render(variant: v, side: 320))
    let x = CGFloat(v - 1) * 400 + 40
    big.draw(in: NSRect(x: x, y: 190, width: 320, height: 320))

    let small = NSImage(size: NSSize(width: 96, height: 96))
    small.addRepresentation(render(variant: v, side: 96))
    small.draw(in: NSRect(x: x, y: 74, width: 96, height: 96))
    let tiny = NSImage(size: NSSize(width: 48, height: 48))
    tiny.addRepresentation(render(variant: v, side: 48))
    tiny.draw(in: NSRect(x: x + 118, y: 74, width: 48, height: 48))
    let mini = NSImage(size: NSSize(width: 32, height: 32))
    mini.addRepresentation(render(variant: v, side: 32))
    mini.draw(in: NSRect(x: x + 186, y: 74, width: 32, height: 32))

    (names[v - 1] as NSString).draw(at: NSPoint(x: x, y: 24), withAttributes: attrs)
    ("실제 Dock 크기 →" as NSString).draw(at: NSPoint(x: x + 232, y: 88), withAttributes: smallAttrs)
}
NSGraphicsContext.restoreGraphicsState()
save(sheet, "\(outDir)/시안비교.png")
print("✅ 생성 완료: \(outDir)")
