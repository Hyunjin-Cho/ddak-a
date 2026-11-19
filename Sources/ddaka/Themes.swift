import Cocoa
import CoreImage
import CoreText

// MARK: - 청소 화면 테마 (#16, 2026-11-17)
//
// 🚨 2026-11-17 오너 결정: 하늘색 단색 화면을 그림 테마로 바꾼다. 실행할 때마다 10장면 중 하나가
// 랜덤으로 나오고(고를 수 없음), 모든 모니터는 같은 장면을 쓴다. 바로 전에 나온 장면은 연속으로 고르지 않는다.
// 그림은 2560×1440(16:9) JPEG, 번들 `Contents/Resources/themes/<id>.jpg`. 원본·프롬프트·시안은 저장소 밖
// `~/Documents/myProjects/ddaka-themes/` 에 있다(스튜디오 맥에만 — Git 밖).
//
// 배치 좌표는 그림 위의 비율(u = 왼쪽→오른쪽 0~1, v = 위→아래 0~1)이다. 시안(HTML)의 `scenes.js` 에서
// 옮겨 왔다 — 시안은 1920×1200 viewBox 에 그림을 x' = −106.67 + 0.8333·x 로 깔았으므로
// u = (x' + 106.67) / 2133.33, v = y' / 1200 로 바꿨다.
//   caption = 제목·마우스 안내 묶음의 가운데, sign = 시간·버튼 묶음의 아래 가운데.
// 🔒 그림을 바꾸면 이 좌표도 그림을 보고 다시 잡는다 — 글자가 동물·해 위에 얹히면 안 된다.

struct Theme {
    let id: String
    let caption: CGPoint   // (u, v)
    let sign: CGPoint      // (u, v)
    let ink: NSColor       // 제목·안내 글자색 (sRGB)
    let lightText: Bool    // 어두운 그림이라 글자를 밝게 쓰는 장면(밤)
    var sky: SkyExtension = .standard   // 세로·좁은 화면에서 그림 위 빈 하늘을 채우는 방식 (#34)
}

/// 2026-11-20 (#34) 오너 결정(C안): 세로·좁은 화면에서 그림 위 빈 하늘을 단색 대신 **그림 자체를 흐려 잇는다**(새로 그리지 않는다).
/// 예전엔 그림 맨 위 8줄 평균색 단색이었는데, 낮잠은 노란 올리브, 올려다보기는 회색(맨 위 줄에 털이 섞임)이 나왔다.
/// 시안 비교(9:16 · 4:3, 10장면): 꽉 채워 흐리기만 쓰면 지평선 장면에서 하늘 위에 흐린 땅 띠가 뜨고,
/// 뒤집어 잇기만 쓰면 위 가장자리에 걸친 것(머리·나무줄기·구름)이 세로 기둥이 된다 → 장면마다 고른다.
enum SkyExtension {
    /// 그림 위쪽 `top`(그림 높이 대비)을 위아래로 뒤집어 빈 하늘 자리에 폭 그대로 늘여 붙이고,
    /// 이음매 `near` → 화면 맨 위 `far` 로 갈수록 더 흐린다(흐림 σ = 화면 폭 × 값).
    /// 이음매에서 그림 윗줄과 윗줄이 맞닿아 경계가 안 보이고, 왼쪽 색은 왼쪽 위로 이어진다.
    case mirror(top: CGFloat, near: CGFloat, far: CGFloat)
    /// 그림을 화면 전체에 꽉 차게(가운데 기준) 키워 크게 흐린 것을 바탕으로 쓴다(흐림 σ = 화면 폭 × 값).
    case cover(blur: CGFloat)

    static let standard = SkyExtension.mirror(top: 0.35, near: 0.03, far: 0.10)
}

private func ink(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

private func uv(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: (x + 106.67) / 2133.33, y: y / 1200)
}

// 2026-11-17: 글자색은 색채 교수 의견(장면당 짙은 잉크 한 색, 작은 글씨 7:1 이상)으로 시안에서 정했다.
let allThemes: [Theme] = [
    Theme(id: "sunset",  caption: uv(1380, 420), sign: uv(1650, 1165), ink: ink(0x2B2552), lightText: false),
    // 2026-11-20 (#34): 바닷가는 위 35% 를 뒤집으면 큰 구름이 흰 기둥처럼 늘어난다 → 위 15% 만, 더 세게 흐린다.
    Theme(id: "beach",   caption: uv(460, 300),  sign: uv(1650, 1165), ink: ink(0x0F3B3C), lightText: false,
          sky: .mirror(top: 0.15, near: 0.06, far: 0.22)),
    Theme(id: "busstop", caption: uv(1300, 250), sign: uv(1620, 1190), ink: ink(0x163240), lightText: false),
    // 2026-11-20 (#34): 비 오는 날·올려다보기는 위 가장자리에 나무줄기·머리가 걸쳐 있어 뒤집어 늘이면 세로 기둥이 된다 → 꽉 채워 흐리기.
    Theme(id: "rain",    caption: uv(1560, 200), sign: uv(1650, 1165), ink: ink(0x22403A), lightText: false,
          sky: .cover(blur: 0.10)),
    Theme(id: "walk",    caption: uv(560, 250),  sign: uv(1650, 1165), ink: ink(0x1E3550), lightText: false),
    Theme(id: "autumn",  caption: uv(520, 230),  sign: uv(300, 1165),  ink: ink(0x1E3550), lightText: false),
    // 2026-11-18 (#31) 오너 지정 — 그림 격자(왼→오 0~10, 아래→위 0~10)로 글자 묶음 가운데 = (8, 7.6), 알약 가운데 = (3, 1).
    //   예전 자리(1080, 115 · 1120, 1180)는 글자가 큰 별똥별 꼬리 두 줄 위에 걸렸다(2560×1440 미리보기 50장 검사).
    //   처음 지정한 (8, 8) 은 제목 왼쪽 끝이 오른쪽 별똥별의 파란 별 머리에 닿아서(2560·1920·1440), 오너가 비교 시안을 보고 (8, 7.6) 으로.
    //   오른쪽으로 비키는 건 안 된다 — 글자 묶음 폭(capW)이 오른쪽 여백에 막혀 (8, 8) 이 이미 한계 근처다.
    //   sign 은 묶음 "아래 끝" 기준이라, 2560×1440 에서 알약 가운데가 아래 10% 에 오도록 아래 끝을 5.44% 에 둔다
    //   (알약 가운데 = 아래 끝 + 65.7pt = 화면의 4.56% · 화면이 작으면 알약이 조금 더 위로: 1440×900 약 11%).
    // 2026-11-20 (#34): 밤은 위 35% 를 뒤집으면 언덕 빛·별똥별 꼬리가 글자 뒤로 올라와 흰 글자 명암비가 1.6~2.0:1 로 떨어졌다
    //   (예전 단색 4.0:1) → 위 10% 만(어두운 하늘), 더 세게 흐림: 9:16 제목 뒤 중앙 4.3 · 최저 3.1:1(옅은 빛기둥이 지나는 곳 — 글자 그림자가 받친다).
    Theme(id: "night",   caption: uv(1600, 288), sign: uv(533, 1135), ink: ink(0xFFF6E6), lightText: true,
          sky: .mirror(top: 0.10, near: 0.06, far: 0.22)),
    Theme(id: "nap",     caption: uv(520, 170),  sign: uv(1650, 1165), ink: ink(0x23402F), lightText: false),
    Theme(id: "lookup",  caption: uv(960, 560),  sign: uv(960, 1180),  ink: ink(0x1E3A5C), lightText: false,
          sky: .cover(blur: 0.10)),
    Theme(id: "snow",    caption: uv(520, 230),  sign: uv(1650, 1165), ink: ink(0x33405A), lightText: false),
]

/// 그림을 못 읽었을 때 쓰는 배치 — 예전 하늘색 바탕에 가운데 정렬(글자색은 하늘색 위에서 읽히는 짙은 청록).
let plainTheme = Theme(id: "plain", caption: CGPoint(x: 0.5, y: 0.42), sign: CGPoint(x: 0.5, y: 0.86),
                       ink: ink(0x1F4B5E), lightText: false)

private let lastThemeKey = "lastThemeID"

/// 랜덤으로 하나 고른다. 바로 전에 나온 장면은 빼고 고른다(같은 그림이 연달아 나오면 "랜덤"이 고장 난 것처럼 보인다).
func pickTheme() -> Theme {
    let last = UserDefaults.standard.string(forKey: lastThemeKey)
    let pool = allThemes.filter { $0.id != last }
    let theme = (pool.isEmpty ? allThemes : pool).randomElement() ?? allThemes[0]
    UserDefaults.standard.set(theme.id, forKey: lastThemeKey)
    return theme
}

// MARK: - 번들 자원

/// 번들 자원 폴더. DEBUG 빌드의 미리보기는 `DDAKA_ASSETS` 로 저장소의 `assets/` 를 가리킬 수 있다.
func resourceURL(_ subdir: String, _ name: String) -> URL? {
    #if DEBUG
    if let root = ProcessInfo.processInfo.environment["DDAKA_ASSETS"] {
        let url = URL(fileURLWithPath: root).appendingPathComponent(subdir).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { return url }
    }
    #endif
    guard let url = Bundle.main.resourceURL?.appendingPathComponent(subdir).appendingPathComponent(name),
          FileManager.default.fileExists(atPath: url.path) else { return nil }
    return url
}

/// 그림과, 그림 맨 위 줄의 평균색(창 바탕색 · 흐린 하늘을 못 만들었을 때 세로 화면 위쪽을 칠하는 색).
/// 🔒 못 읽으면 nil — 부르는 쪽은 예전 하늘색 단색으로 물러나고 글자·버튼은 그대로 그린다.
struct ThemeArt {
    let image: NSImage
    let cgImage: CGImage   // 2026-11-20 (#34): 세로 화면의 흐린 하늘을 만들 원본
    let topColor: NSColor

    static func load(_ theme: Theme) -> ThemeArt? {
        guard let url = resourceURL("themes", "\(theme.id).jpg"),
              let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        // 맨 위 8줄을 1×1 로 줄여 그리면 그 평균색이 남는다.
        var px = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        if let strip = cg.cropping(to: CGRect(x: 0, y: 0, width: cg.width, height: 8)),
           let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                               space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.interpolationQuality = .medium
            ctx.draw(strip, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let top = NSColor(srgbRed: CGFloat(px[0]) / 255, green: CGFloat(px[1]) / 255, blue: CGFloat(px[2]) / 255, alpha: 1)
        return ThemeArt(image: image, cgImage: cg, topColor: top)
    }
}

// MARK: - 글꼴

/// 2026-11-17 오너: 고운돋움(Gowun Dodum, SIL OFL 1.1 — `fonts/OFL-GowunDodum.txt`).
/// 쓰는 글자만 남긴 서브셋(KS X 1001 한글 2,350자 + 라틴)이라 1.2MB 다. 이 앱 프로세스에만 등록한다.
/// 2026-11-18 (#25) 오너: 일본어·중국어도 고운돋움과 결이 맞게 — 비교 시안에서 일 B′ · 중 B 를 골랐다.
///   일 = Klee One(+ palt) · 간 = Ddaka Kai SC(LXGW WenKai 서브셋 — 예약된 글꼴 이름 때문에 이름만 바꿈) · 번 = LXGW WenKai TC.
///   셋 다 SIL OFL 1.1, 청소 화면 문구 글자만 남긴 서브셋이다(`assets/fonts/README.md` · `make-subsets.sh`).
///   예전 짝(히라기노 둥근 고딕 · 핑팡)은 넣은 글꼴을 못 찾을 때의 대비로 남긴다. 그것도 없으면 시스템 글꼴 — 글자가 안 보이는 일은 없다.
/// 🔒 언어 ↔ 글꼴 짝을 바꾸면 `assets/fonts/check-overlay-glyphs.swift` 의 표도 같이 바꾼다(빌드 때 글자 검사가 그 표를 본다).
let bundledFontFiles = ["GowunDodum-Regular.ttf", "KleeOne-Regular.ttf", "DdakaKaiSC-Regular.ttf", "LXGWWenKaiTC-Regular.ttf"]

let bundledFontsRegistered: Bool = {
    var allRegistered = true
    for file in bundledFontFiles {
        guard let url = resourceURL("fonts", file), CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) else {
            // 실패해도 화면은 예비 글꼴로 정상이라 눈으로는 모른다 → 원인을 찾을 단서로 한 줄 남긴다(2026-11-18 리뷰).
            appLog.error("fonts: could not register \(file, privacy: .public)")
            allRegistered = false
            continue
        }
    }
    return allRegistered
}()

func overlayFont(size: CGFloat) -> NSFont {
    _ = bundledFontsRegistered
    let (name, fallback): (String, String?)
    switch uiLanguage {
    case .en, .ko: (name, fallback) = ("GowunDodum-Regular", nil)
    case .ja: (name, fallback) = ("KleeOne-Regular", "HiraMaruProN-W4")
    case .zhHans: (name, fallback) = ("DdakaKaiSC-Regular", "PingFangSC-Regular")
    case .zhHant: (name, fallback) = ("LXGWWenKaiTC-Regular", "PingFangTC-Regular")
    }
    if let font = NSFont(name: name, size: size) {
        return uiLanguage == .ja ? proportionalKana(font) : font
    }
    if let fallback = fallback, let font = NSFont(name: fallback, size: size) { return font }
    return NSFont.systemFont(ofSize: size, weight: .medium)
}

/// 2026-11-18 (#25): Klee One 의 가나는 전각 폭이라 글자 사이가 듬성해 보인다(비교 시안 B) →
/// OpenType `palt`(가나를 비례 폭으로)를 켠다(비교 시안 B′). 기능이 없는 글꼴이면 CoreText 가 조용히 무시한다.
private func proportionalKana(_ font: NSFont) -> NSFont {
    let palt: [NSFontDescriptor.FeatureKey: Any] = [
        NSFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureTag as String): "palt",
        NSFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureValue as String): 1,
    ]
    let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: [palt]])
    return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
}

/// 숫자는 언어와 상관없이 고운돋움(없으면 시스템 고정폭 숫자).
func countdownFontNamed(size: CGFloat) -> NSFont {
    _ = bundledFontsRegistered
    return NSFont(name: "GowunDodum-Regular", size: size) ?? NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
}

/// "⌘⇧9" 기호는 고운돋움에 없고, 일본어 글꼴의 ⇧ 는 가는 막대처럼 보인다(시안 2026-11-17 실측) → 기호만 따로.
func shortcutAttributed(_ text: String, size: CGFloat, color: NSColor, shadow: NSShadow?) -> NSAttributedString {
    let base: [NSAttributedString.Key: Any] = {
        var a: [NSAttributedString.Key: Any] = [.font: overlayFont(size: size), .foregroundColor: color]
        if let shadow = shadow { a[.shadow] = shadow }
        return a
    }()
    let out = NSMutableAttributedString(string: text, attributes: base)
    if let range = text.range(of: "⌘⇧9") {
        let keys = NSFont(name: "AppleSDGothicNeo-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
        out.addAttributes([.font: keys, .kern: size * 0.06], range: NSRange(range, in: text))
    }
    return out
}

// MARK: - 카운트다운 (숫자마다 같은 폭 칸)

/// 고운돋움 숫자는 폭이 제각각이라, 그대로 두면 1초마다 시간 글자가 좌우로 흔들린다.
/// 글자마다 같은 폭 칸에 가운데 맞춰 그린다(시안 ui.js 와 같은 방식).
final class CountdownView: NSView {
    var text = "00:00" { didSet { if text != oldValue { needsDisplay = true } } }
    let font: NSFont
    let color: NSColor
    private let digitCell: CGFloat
    private let colonCell: CGFloat

    init(font: NSFont, color: NSColor) {
        self.font = font
        self.color = color
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        digitCell = (0...9).map { (String($0) as NSString).size(withAttributes: attrs).width }.max() ?? font.pointSize * 0.6
        colonCell = (":" as NSString).size(withAttributes: attrs).width * 1.3
        super.init(frame: .zero)
        setFrameSize(intrinsicContentSize)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: ceil(digitCell * 4 + colonCell), height: ceil(font.ascender - font.descender + 2))
    }

    override func draw(_ dirtyRect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        var x: CGFloat = 0
        for ch in text {
            let cell = ch == ":" ? colonCell : digitCell
            let s = String(ch) as NSString
            let w = s.size(withAttributes: attrs).width
            let y = (bounds.height - (font.ascender - font.descender)) / 2 + (ch == ":" ? font.pointSize * 0.04 : 0)
            s.draw(at: NSPoint(x: x + (cell - w) / 2, y: y), withAttributes: attrs)
            x += cell
        }
    }
}

// MARK: - 알약 (시간 + 버튼을 담는 반투명 종이)

/// 2026-11-17 오너: 나무 팻말 대신 판 없는 "최소형". 그림을 가장 덜 가린다.
/// 그림 위에서도 숫자가 읽히도록 크림색 종이를 반투명(78%)으로 깐다. 테두리는 아주 옅은 흰 선.
final class PillView: NSView {
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 6, dy: 6)
        let path = NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(srgbRed: 60 / 255, green: 70 / 255, blue: 60 / 255, alpha: 0.16)
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        NSColor(srgbRed: 1, green: 251 / 255, blue: 243 / 255, alpha: 0.78).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor(white: 1, alpha: 0.6).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

/// 세로·좁은 화면에서 그림 윗변 → 이어 칠한 하늘로 번지는 띠(아래 투명 → 위 하늘색).
/// 2026-11-20 (#34): 이제는 흐린 하늘(`makeSkyExtension`)을 못 만들었을 때만 쓴다(예전 단색 방식으로 물러나기).
final class SkyFadeView: NSView {
    var color: NSColor = .clear
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: color.withAlphaComponent(0), ending: color)?.draw(in: bounds, angle: 90)
    }
}

// MARK: - 세로·좁은 화면의 흐린 하늘 (#34, 2026-11-20)

/// 흐림은 sRGB(감마) 공간에서 한다 — 오너가 고른 시안(PIL)과 같은 번짐. 선형 공간이면 밝은 해·구름이 더 크게 번진다.
private let skyContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

/// 그림 위 빈 하늘을 채울 그림을 만든다 — 화면 맨 위부터 그림 윗변 아래 `band`(pt)까지.
/// 맨 아래 `band` 는 아래로 갈수록 투명해져 선명한 그림으로 번진다(예전 SkyFadeView 와 같은 14% 띠).
/// 흐린 그림이라 폭 480px 로 작게 만들어 화면 크기로 키워 그린다 — 계산이 가볍고 키워도 티가 안 난다.
/// 🔒 실패하면 nil — 부르는 쪽은 예전 단색 + 번짐 띠로 물러난다.
func makeSkyExtension(_ art: CGImage, style: SkyExtension, screen: CGSize, band: CGFloat) -> CGImage? {
    let ww: CGFloat = 480
    let k = ww / screen.width                       // pt → 작업 px
    let hh = (screen.height * k).rounded()
    let imgW = CGFloat(art.width), imgH = CGFloat(art.height)
    let sx = ww / imgW
    let ah = imgH * sx                              // 작업 캔버스에서 그림 높이 (Core Image 는 아래가 0 — 그림은 [0, ah])
    let bandPx = band * k
    guard hh > ah + 1 else { return nil }
    let canvas = CGRect(x: 0, y: 0, width: ww, height: hh)
    let src = CIImage(cgImage: art)
    func blur(_ img: CIImage, _ fraction: CGFloat) -> CIImage {
        img.clampedToExtent().applyingGaussianBlur(sigma: Double(fraction * ww)).cropped(to: canvas)
    }
    func ramp(black p0: CGPoint, white p1: CGPoint) -> CIImage? {
        // 세로 그라데이션 마스크 p0 검정 → p1 흰색(끝점 밖은 끝 색 그대로)
        CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(cgPoint: p0), "inputPoint1": CIVector(cgPoint: p1),
            "inputColor0": CIColor(red: 0, green: 0, blue: 0), "inputColor1": CIColor(red: 1, green: 1, blue: 1),
        ])?.outputImage?.cropped(to: canvas)
    }

    var sky: CIImage
    switch style {
    case let .mirror(top, near, far):
        // 그림 위쪽 top 을 뒤집어 [ah, hh] 에 폭 그대로 늘인다 — 그림 맨 윗줄이 이음매(ah)에, top 지점이 화면 맨 위(hh)에.
        let sy = (hh - ah) / (top * imgH)
        let flipped = src.cropped(to: CGRect(x: 0, y: imgH * (1 - top), width: imgW, height: imgH * top))
            .transformed(by: CGAffineTransform(a: sx, b: 0, c: 0, d: -sy, tx: 0, ty: ah + imgH * sy))
        // 아래는 그림 그대로 둬야 이음매 근처 흐림이 그림 색을 끌어온다(빈 곳의 검정·투명이 번져 들지 않게).
        let ext = flipped.composited(over: src.transformed(by: CGAffineTransform(scaleX: sx, y: sx)))
        guard let mask = ramp(black: CGPoint(x: 0, y: hh), white: CGPoint(x: 0, y: ah)) else { return nil }
        sky = blur(ext, near).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: blur(ext, far), kCIInputMaskImageKey: mask])   // 이음매(흰색) near → 맨 위(검정) far
    case let .cover(amount):
        let sc = max(ww / imgW, hh / imgH)
        let cover = src.transformed(by: CGAffineTransform(scaleX: sc, y: sc))
            .transformed(by: CGAffineTransform(translationX: (ww - imgW * sc) / 2, y: (hh - imgH * sc) / 2))
        sky = blur(cover, amount)
    }
    // 맨 아래 band: 그림 윗변(ah)에서 불투명 → band 아래 끝에서 투명
    guard let fade = ramp(black: CGPoint(x: 0, y: ah - bandPx), white: CGPoint(x: 0, y: ah)) else { return nil }
    sky = sky.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: fade])
    let out = CGRect(x: 0, y: (ah - bandPx).rounded(.down), width: ww, height: hh - (ah - bandPx).rounded(.down))
    return skyContext.createCGImage(sky, from: out, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
}
