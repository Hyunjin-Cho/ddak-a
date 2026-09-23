import Cocoa
import QuartzCore

// AI가 만든 정사각 아이콘을 macOS 규격으로 다듬는다 — 2026-09-22
// (1) Apple 고유의 모서리 곡선(continuous corner / squircle)으로 깎고
// (2) 1024 캔버스 안에 824 크기로 넣는다 — 다른 앱 아이콘과 크기·정렬을 맞추기 위한 표준 여백
//
// 사용법: swift mask.swift <입력.png> <출력-1024.png> [<비교시트.png>]
// SVG 에서 AppIcon.icns 까지 한 번에 만들려면 같은 폴더의 make-icon.sh 를 쓴다.
//
// 🚨 2026-09-23 (#11): 입력·출력 경로를 인자로 받게 바꿨다.
//   종전에는 `swift mask.swift <폴더>` 로 그 폴더의 `ai-soft3d-trim.svg.png` 를 읽고
//   `ai-soft3d-mac-1024.png` · `검증-크기별-v2.png` 를 썼다. 그 입력 파일은 저장소에 없었고 출력 이름도
//   커밋된 이름(AppIcon-1024.png · 검증-크기별.png)과 달라서, 저장소만으로는 아이콘을 다시 만들 수 없었다.
//   인자가 모자라거나 파일을 못 읽으면 강제 언래핑(!)으로 죽던 것도 사용법 안내 + 0 이 아닌 종료 코드로 바꿨다.
// 🔒 2026-09-23 (#11): 그리는 계산(824 본체 · 모서리 0.2237 · resizeAspectFill · DeviceRGB 캔버스 · 시트 배치)은
//   그대로 옮겼다. 여기를 바꾸면 커밋된 AppIcon-1024.png 와 더 이상 같게 나오지 않는다(make-icon.sh 가 끝에 대조한다).

let usage = """
사용법: swift mask.swift <입력.png> <출력-1024.png> [<비교시트.png>]
  <입력.png>       정사각 원본 — 여백 없이 꽉 찬 그림 (make-icon.sh 에서는 Quick Look 으로 그린 1024 PNG)
  <출력-1024.png>  모서리 곡선 + 표준 여백을 입힌 1024 아이콘
  <비교시트.png>   (선택) 원본과 결과를 256·128·64·32·16px 로 줄여 나란히 놓은 확인용 시트
"""

/// 사용자에게 보이는 실패는 강제 언래핑으로 죽지 않고, 이유를 말한 뒤 0 이 아닌 코드로 끝낸다
func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func loadCG(_ path: String) -> CGImage {
    guard let data = FileManager.default.contents(atPath: path) else {
        fail("❌ 입력 파일을 읽지 못했어: \(path)")
    }
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        fail("❌ 이미지로 읽을 수 없는 파일이야: \(path)")
    }
    return img
}

/// 8bit RGBA(premultiplied) 그림판 — 아이콘·축소본·시트가 모두 같은 형식을 쓴다
func makeContext(_ width: Int, _ height: Int) -> CGContext {
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("❌ \(width)x\(height) 그림판을 만들지 못했어")
    }
    return ctx
}

func snapshot(_ ctx: CGContext) -> CGImage {
    guard let img = ctx.makeImage() else { fail("❌ 그림판에서 이미지를 꺼내지 못했어") }
    return img
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

    let ctx = makeContext(Int(canvas), Int(canvas))
    ctx.saveGState()
    ctx.translateBy(x: inset, y: inset)
    layer.render(in: ctx)
    ctx.restoreGState()
    return snapshot(ctx)
}

func scaled(_ img: CGImage, _ side: CGFloat) -> CGImage {
    let ctx = makeContext(Int(side), Int(side))
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: side, height: side))
    return snapshot(ctx)
}

func savePNG(_ img: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fail("❌ PNG 로 바꾸지 못했어: \(path)")
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
    } catch {
        fail("❌ 저장하지 못했어: \(path)\n   \(error.localizedDescription)")
    }
}

/// 비교 시트 — 위: AI 원본 그대로 / 아래: macOS 규격 적용. 오른쪽으로 갈수록 실제 사용 크기
func makeSheet(_ src: CGImage, _ masked: CGImage) -> CGImage {
    let sizes: [CGFloat] = [256, 128, 64, 32, 16]
    let sheetW: CGFloat = 1180, sheetH: CGFloat = 700
    let ctx = makeContext(Int(sheetW), Int(sheetH))
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
    return snapshot(ctx)
}

let args = Array(CommandLine.arguments.dropFirst())
if args.count == 1, args[0] == "-h" || args[0] == "--help" {
    print(usage)
    exit(0)
}
guard args.count == 2 || args.count == 3 else {
    fail(usage, code: 2)
}
let inputPath = args[0], outputPath = args[1]
let sheetPath: String? = args.count == 3 ? args[2] : nil

// 저장할 폴더가 없으면 그리기 전에 멈춘다 — 저장 단계의 시스템 메시지("파일이 없다")는 원인을 가린다
for path in [outputPath, sheetPath].compactMap({ $0 }) {
    let dir = (path as NSString).deletingLastPathComponent
    var isDir: ObjCBool = false
    if !dir.isEmpty, !(FileManager.default.fileExists(atPath: dir, isDirectory: &isDir) && isDir.boolValue) {
        fail("❌ 저장할 폴더가 없어: \(dir)")
    }
}

let src = loadCG(inputPath)
if src.width != src.height {
    // 막지는 않는다 — resizeAspectFill 이 가운데를 기준으로 긴 쪽을 잘라 쓴다
    FileHandle.standardError.write(Data(
        "⚠️ 입력이 정사각이 아니다 (\(src.width)x\(src.height)) — 가운데를 기준으로 긴 쪽이 잘린다\n".utf8))
}
let masked = makeMacIcon(src)
savePNG(masked, outputPath)
print("✅ \(outputPath)")
fflush(stdout)   // 파이프로 넘길 때도 오류 메시지(stderr)와 순서가 섞이지 않게

if let sheetPath = sheetPath {
    savePNG(makeSheet(src, masked), sheetPath)
    print("✅ \(sheetPath)")
}
