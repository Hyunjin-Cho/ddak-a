import Cocoa
// 닦아 DMG 배경 v2 (2026-09-22) — 글자·화살표 대비를 크게 올리고 아이콘 자리를 128px 기준으로 넓혔다
let W: CGFloat = 640, H: CGFloat = 400
let appC  = CGPoint(x: 165, y: 215)   // Finder 좌표(좌상단 원점) — 아이콘 중심
let applC = CGPoint(x: 475, y: 215)
func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: H - p.y) }

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W*scale), pixelsHigh: Int(H*scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 배경 — 거의 흰색에 가깝게. 글자와 아이콘이 주인공이고 배경은 물러난다.
    NSGradient(starting: NSColor(calibratedRed: 0.97, green: 0.985, blue: 1.0, alpha: 1),
               ending:   NSColor(calibratedRed: 0.90, green: 0.945, blue: 0.975, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    func center(_ s: String, _ a: [NSAttributedString.Key: Any], yTop: CGFloat) {
        let ns = s as NSString
        let sz = ns.size(withAttributes: a)
        ns.draw(at: NSPoint(x: (W - sz.width)/2, y: H - yTop - sz.height), withAttributes: a)
    }
    // 위: 작고 옅은 안내 / 아래: 크고 진한 지시 — 시선이 두 번째 줄에 꽂히게 한다
    center("닦아를 설치하려면", [
        .font: NSFont.systemFont(ofSize: 15, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.42, alpha: 1)], yTop: 42)
    center("아이콘을 응용 프로그램 폴더로 드래그하세요", [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.16, alpha: 1)], yTop: 68)
    center("Drag the icon into the Applications folder", [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1)], yTop: 104)

    // 화살표 — 짧고 굵고 진하게. 아이콘 128px 기준이라 양옆 여백을 78 로 잡는다.
    let a = flip(appC), b = flip(applC)
    let inset: CGFloat = 78
    let x1 = a.x + inset, x2 = b.x - inset, y = a.y
    let head: CGFloat = 30
    let blue = NSColor(calibratedRed: 0.22, green: 0.47, blue: 0.87, alpha: 1)
    blue.setFill(); blue.setStroke()
    let bar = NSBezierPath()
    bar.move(to: NSPoint(x: x1, y: y))
    bar.line(to: NSPoint(x: x2 - head + 2, y: y))
    bar.lineWidth = 15
    bar.lineCapStyle = .butt
    bar.stroke()
    let tip = NSBezierPath()
    tip.move(to: NSPoint(x: x2, y: y))
    tip.line(to: NSPoint(x: x2 - head, y: y + head * 0.72))
    tip.line(to: NSPoint(x: x2 - head, y: y - head * 0.72))
    tip.close(); tip.fill()

    center("여기서 바로 실행하지 말고, 옮긴 뒤에 실행해 주세요", [
        .font: NSFont.systemFont(ofSize: 12, weight: .medium),
        .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.10, alpha: 1)], yTop: 340)
    center("Move it to Applications first, then open", [
        .font: NSFont.systemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.48, alpha: 1)], yTop: 360)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}
let dir = CommandLine.arguments[1]
for (n, s) in [("bg2.png", CGFloat(1)), ("bg2@2x.png", CGFloat(2))] {
    try! render(scale: s).representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(dir)/\(n)"))
}
print("✅ 배경 v2 생성")
