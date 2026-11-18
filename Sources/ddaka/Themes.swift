import Cocoa
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
    Theme(id: "beach",   caption: uv(460, 300),  sign: uv(1650, 1165), ink: ink(0x0F3B3C), lightText: false),
    Theme(id: "busstop", caption: uv(1300, 250), sign: uv(1620, 1190), ink: ink(0x163240), lightText: false),
    Theme(id: "rain",    caption: uv(1560, 200), sign: uv(1650, 1165), ink: ink(0x22403A), lightText: false),
    Theme(id: "walk",    caption: uv(560, 250),  sign: uv(1650, 1165), ink: ink(0x1E3550), lightText: false),
    Theme(id: "autumn",  caption: uv(520, 230),  sign: uv(300, 1165),  ink: ink(0x1E3550), lightText: false),
    Theme(id: "night",   caption: uv(1080, 115), sign: uv(1120, 1180), ink: ink(0xFFF6E6), lightText: true),
    Theme(id: "nap",     caption: uv(520, 170),  sign: uv(1650, 1165), ink: ink(0x23402F), lightText: false),
    Theme(id: "lookup",  caption: uv(960, 560),  sign: uv(960, 1180),  ink: ink(0x1E3A5C), lightText: false),
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

/// 그림과, 세로·좁은 화면에서 그림 위쪽을 이어 칠할 하늘색(그림 맨 위 줄의 평균색).
/// 🔒 못 읽으면 nil — 부르는 쪽은 예전 하늘색 단색으로 물러나고 글자·버튼은 그대로 그린다.
struct ThemeArt {
    let image: NSImage
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
        return ThemeArt(image: image, topColor: top)
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
final class SkyFadeView: NSView {
    var color: NSColor = .clear
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: color.withAlphaComponent(0), ending: color)?.draw(in: bounds, angle: 90)
    }
}
