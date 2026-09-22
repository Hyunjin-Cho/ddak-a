import Cocoa
import QuartzCore

// AI가 만든 정사각 아이콘을 macOS 규격으로 다듬는다 — 2026-09-22
// (1) Apple 고유의 모서리 곡선(continuous corner / squircle)으로 깎고
// (2) 1024 캔버스 안에 824 크기로 넣는다 — 다른 앱 아이콘과 크기·정렬을 맞추기 위한 표준 여백

func loadCG(_ path: String) -> CGImage {
    let data = NSData(contentsOfFile: path)!
    let src = CGImageSourceCreateWithData(data, nil)!
    return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}

/// Apple 모서리 곡선으로 깎은 뒤 표준 여백을 준 1024 아이콘
func makeMacIcon(_ source: CGImage, canvas: CGFloat = 1024, bodyRatio: CGFloat = 824.0 / 1024.0) -> CGImage {
    let body = (canvas * bodyRatio).rounded()
    let inset = ((canvas - body) / 2).rounded()

    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: body, height: body)
    layer.contents = source
    layer.contentsGravity = .resizeAspectFill
    layer.cornerRadius = body * 0.2237      // Apple 아이콘 모서리 비율
    layer.cornerCurve = .continuous          // 단순 원호가 아닌 Apple 특유의 연속 곡선
    layer.masksToBounds = true

    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.saveGState()
    ctx.translateBy(x: inset, y: inset)
    layer.render(in: ctx)
    ctx.restoreGState()
    return ctx.makeImage()!
}

func scaled(_ img: CGImage, _ side: CGFloat) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: side, height: side))
    return ctx.makeImage()!
}

func savePNG(_ img: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let dir = CommandLine.arguments[1]
let src = loadCG("\(dir)/ai-soft3d-trim.svg.png")
let masked = makeMacIcon(src)
savePNG(masked, "\(dir)/ai-soft3d-mac-1024.png")

// 비교 시트 — 위: AI 원본 그대로 / 아래: macOS 규격 적용. 오른쪽으로 갈수록 실제 사용 크기
let sizes: [CGFloat] = [256, 128, 64, 32, 16]
let sheetW: CGFloat = 1180, sheetH: CGFloat = 700
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(sheetW), height: Int(sheetH), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ns

NSColor(calibratedWhite: 0.16, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()

let head: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: NSColor.white]
let small: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.68, alpha: 1.0)]

("AI 원본 그대로 (정사각 · 여백 없음)" as NSString).draw(at: NSPoint(x: 40, y: 650), withAttributes: head)
("macOS 규격 적용 (모서리 곡선 + 표준 여백)" as NSString).draw(at: NSPoint(x: 40, y: 300), withAttributes: head)

var x: CGFloat = 40
for s in sizes {
    let a = scaled(src, s), b = scaled(masked, s)
    ctx.draw(a, in: CGRect(x: x, y: 640 - s, width: s, height: s))
    ctx.draw(b, in: CGRect(x: x, y: 290 - s, width: s, height: s))
    ("\(Int(s))px" as NSString).draw(at: NSPoint(x: x, y: 640 - s - 26), withAttributes: small)
    ("\(Int(s))px" as NSString).draw(at: NSPoint(x: x, y: 290 - s - 26), withAttributes: small)
    x += s + 60
}
NSGraphicsContext.restoreGraphicsState()
savePNG(ctx.makeImage()!, "\(dir)/검증-크기별-v2.png")
print("✅ 완료")
