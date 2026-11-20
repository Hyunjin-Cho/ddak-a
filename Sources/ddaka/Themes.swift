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
/// 같은 날 오너 2차 지시(장면별 돌리기·절반 반복·조각 따오기·별)로 재료를 만드는 법을 나눠 적게 했다.
struct SkyExtension {
    /// 빈 하늘 자리(화면 폭 × 그림 윗변 위)에 깔 재료.
    enum Source {
        /// 그림 위쪽 `fraction`(그림 높이 대비)을 폭 그대로 늘인다. `flip` 이면 위아래를 뒤집어 그림 맨 윗줄이 이음매에 온다(경계가 안 보인다).
        case top(CGFloat, flip: Bool)
        /// 그림의 한 조각(u, v, 폭, 높이 — 그림 대비, v 는 위에서부터)을 비율 그대로 빈 하늘에 꽉 채운다(가운데 기준).
        case patch(CGRect)
        /// 그림을 화면 전체에 꽉 차게(가운데 기준) 키운다 — 돌리기·반복·섞기는 쓰지 않는다.
        case wholeScreen
    }
    var source: Source
    var near: CGFloat            // 이음매의 흐림 σ (화면 폭 대비)
    var far: CGFloat             // 화면 맨 위의 흐림 σ — 그 사이는 위로 갈수록 더 흐리게
    var turn = 0                 // +1 시계 90° · −1 반시계 90° — 만든 재료를 돌려 다시 빈 하늘 크기로
    var echo = false             // 재료의 아래 절반(이음매 쪽)을 180° 돌려 위 절반에 한 번 더
    var seam: CGFloat = 0        // 이음매 위 이 비율만큼 '위아래 뒤집은 그림 위 15%'로 섞는다(돌리거나 그대로 늘인 재료의 경계 줄 없애기)
    var overlay: Overlay? = nil  // 재료 위에 그림의 다른 조각을 가장자리를 부드럽게 따서 얹는다(구름을 하늘 가운데에)
    var stars = false            // 별을 흩뿌린다(`makeStarLayer` — 화면 해상도로 따로 얹는다)

    /// 얹을 조각 — patch 는 Source.patch 와 같은 꼴, center 는 빈 하늘 대비(x 왼→오, y 위→아래), width 는 화면 폭 대비.
    struct Overlay {
        var patch: CGRect
        var center: CGPoint
        var width: CGFloat
    }

    static let standard = SkyExtension(source: .top(0.35, flip: true), near: 0.03, far: 0.10)
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
    //   오너 2차: 그래도 남는 세로 구름 줄을 가로로 — 만든 재료만 반시계 90° 돌린다(아래 끝이 그림 윗줄과 다르니 이음매를 섞는다).
    Theme(id: "beach",   caption: uv(460, 300),  sign: uv(1650, 1165), ink: ink(0x0F3B3C), lightText: false,
          sky: SkyExtension(source: .top(0.15, flip: true), near: 0.06, far: 0.22, turn: -1, seam: 0.3)),
    // 2026-11-20 (#34) 오너 2차: 뒤집은 정류장 지붕이 왼쪽 위 초록 얼룩으로 보였다("180도 돌아간 게 느껴진다")
    //   → 재료의 아래 절반(하늘)만 180° 돌려 위 절반에 한 번 더 — 하늘이 이어지는 느낌.
    //   오너 3차: 그래도 위쪽 분홍 구름이 거꾸로인 게 보인다 → 바닷가처럼 반시계 90° 돌려 구름을 가로로 눕힌다.
    Theme(id: "busstop", caption: uv(1300, 250), sign: uv(1620, 1190), ink: ink(0x163240), lightText: false,
          sky: SkyExtension(source: .top(0.35, flip: true), near: 0.03, far: 0.10, turn: -1, echo: true, seam: 0.3)),
    // 2026-11-20 (#34): 비 오는 날은 위 가장자리에 나무줄기가 걸쳐 있어 뒤집어 늘이면 세로 기둥이 된다.
    //   그림 위에 나무 윗부분이 없어 수관을 이을 수는 없다 → 오른쪽 위 안개 낀 하늘 조각으로 채우고, 이음매 위 35% 만
    //   뒤집은 그림(나무)을 섞어 나무가 위로 갈수록 안개에 잠기게 한다(오너 3차: "진짜 자연스럽다").
    Theme(id: "rain",    caption: uv(1560, 200), sign: uv(1650, 1165), ink: ink(0x22403A), lightText: false,
          sky: SkyExtension(source: .patch(CGRect(x: 0.66, y: 0, width: 0.34, height: 0.28)), near: 0.03, far: 0.10, seam: 0.35)),
    // 2026-11-20 (#34) 오너 2차: 뒤집으면 오른쪽 노을빛이 오른쪽 위 구석에 떨어져 동떨어져 보였다 → 시계 90° 돌려 봤고,
    //   오너 3차: 노을빛 없이 파란 하늘만 → 왼쪽 위 파란 하늘 조각(풀 줄기·비행운·노을 없음)으로 채운다. 이음매는 섞는다.
    Theme(id: "walk",    caption: uv(560, 250),  sign: uv(1650, 1165), ink: ink(0x1E3550), lightText: false,
          sky: SkyExtension(source: .patch(CGRect(x: 0, y: 0, width: 0.48, height: 0.24)), near: 0.03, far: 0.10, seam: 0.3)),
    Theme(id: "autumn",  caption: uv(520, 230),  sign: uv(300, 1165),  ink: ink(0x1E3550), lightText: false),
    // 2026-11-18 (#31) 오너 지정 — 그림 격자(왼→오 0~10, 아래→위 0~10)로 글자 묶음 가운데 = (8, 7.6), 알약 가운데 = (3, 1).
    //   예전 자리(1080, 115 · 1120, 1180)는 글자가 큰 별똥별 꼬리 두 줄 위에 걸렸다(2560×1440 미리보기 50장 검사).
    //   처음 지정한 (8, 8) 은 제목 왼쪽 끝이 오른쪽 별똥별의 파란 별 머리에 닿아서(2560·1920·1440), 오너가 비교 시안을 보고 (8, 7.6) 으로.
    //   오른쪽으로 비키는 건 안 된다 — 글자 묶음 폭(capW)이 오른쪽 여백에 막혀 (8, 8) 이 이미 한계 근처다.
    //   sign 은 묶음 "아래 끝" 기준이라, 2560×1440 에서 알약 가운데가 아래 10% 에 오도록 아래 끝을 5.44% 에 둔다
    //   (알약 가운데 = 아래 끝 + 65.7pt = 화면의 4.56% · 화면이 작으면 알약이 조금 더 위로: 1440×900 약 11%).
    // 2026-11-20 (#34): 밤은 위를 뒤집으면 언덕 빛·별똥별 꼬리가 글자 뒤로 올라와 흰 글자 명암비가 1.6~2.0:1 로 떨어졌다(예전 단색 4.0:1).
    //   오너 2차: 별똥별은 빼고 밤하늘과 그 안의 작은 별만으로 → 오른쪽 위 밤하늘 조각(별똥별·비눗방울 없음)을 통째로 키워 흐린 바탕 +
    //   별(오너 3차: 흐리게 · 더 무작위로 · 크기도 흐림 세기도 제각각 — `makeStarLayer`). 9:16 제목 뒤 명암비 중앙 6.1:1.
    Theme(id: "night",   caption: uv(1600, 288), sign: uv(533, 1135), ink: ink(0xFFF6E6), lightText: true,
          sky: SkyExtension(source: .patch(CGRect(x: 0.82, y: 0, width: 0.18, height: 0.17)), near: 0.03, far: 0.10, stars: true)),
    // 2026-11-20 (#34) 오너 2차: 강아지가 안 걸리는 위 30% 를 뒤집지 않고 그대로 위로 늘여 흐린다(위가 밝은 빛, 이음매 쪽이 풀).
    //   아래 끝(그림 30% 줄)이 그림 윗줄과 달라 이음매를 섞는다.
    Theme(id: "nap",     caption: uv(520, 170),  sign: uv(1650, 1165), ink: ink(0x23402F), lightText: false,
          sky: SkyExtension(source: .top(0.30, flip: false), near: 0.03, far: 0.10, seam: 0.3)),
    // 2026-11-20 (#34) 오너 2차: 꽉 채워 흐리면 큰 해와 털 덩어리가 보였다 → "하늘과 구름이 보여야".
    //   오너 3차: 구름 조각을 통째로 채우면 구름이 그림 바로 위에 붙어 어색하다 → 구름 없는 가운데 하늘 조각을 바탕으로 깔고,
    //   오른쪽 구름 조각을 가장자리를 부드럽게 따서 빈 하늘 가운데 오른쪽에 얹는다. 이음매 섞기는 안 쓴다(그림 윗줄의 머리가 끌려 올라온다).
    Theme(id: "lookup",  caption: uv(960, 560),  sign: uv(960, 1180),  ink: ink(0x1E3A5C), lightText: false,
          sky: SkyExtension(source: .patch(CGRect(x: 0.42, y: 0.33, width: 0.20, height: 0.29)), near: 0.015, far: 0.05,
                            overlay: .init(patch: CGRect(x: 0.58, y: 0.46, width: 0.18, height: 0.30), center: CGPoint(x: 0.62, y: 0.50), width: 0.95))),
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
/// 흐린 그림이라 폭 480px 로 작게 만들어 화면 크기로 키워 그린다 — 계산이 가볍고 키워도 티가 안 난다(별은 따로 — `makeStarLayer`).
/// 🔒 실패하면 nil — 부르는 쪽은 예전 단색 + 번짐 띠로 물러난다.
func makeSkyExtension(_ art: CGImage, style: SkyExtension, screen: CGSize, band: CGFloat) -> CGImage? {
    let ww: CGFloat = 480
    let k = ww / screen.width                       // pt → 작업 px
    let hh = (screen.height * k).rounded()
    let imgW = CGFloat(art.width), imgH = CGFloat(art.height)
    let sx = ww / imgW
    let ah = imgH * sx                              // 작업 캔버스에서 그림 높이 (Core Image 는 아래가 0 — 그림은 [0, ah], 빈 하늘은 [ah, hh])
    let sh = hh - ah
    let bandPx = band * k
    guard sh > 1 else { return nil }
    let canvas = CGRect(x: 0, y: 0, width: ww, height: hh)
    let skyRect = CGRect(x: 0, y: ah, width: ww, height: sh)
    let src = CIImage(cgImage: art)
    let artPlaced = src.transformed(by: CGAffineTransform(scaleX: sx, y: sx))
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
    /// 그림 대비 조각(v 는 위에서부터) → Core Image 픽셀 사각형(아래가 0)
    func ciRect(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX * imgW, y: imgH * (1 - r.minY - r.height), width: r.width * imgW, height: r.height * imgH)
    }
    /// 그림 위쪽 띠를 빈 하늘 자리에 폭 그대로 늘인다 — flip 이면 맨 윗줄이 이음매(ah)에, 아니면 맨 위(hh)에.
    func topBand(_ f: CGFloat, flip: Bool) -> CIImage {
        let sy = sh / (f * imgH)
        let band = src.cropped(to: CGRect(x: 0, y: imgH * (1 - f), width: imgW, height: imgH * f))
        let t = flip ? CGAffineTransform(a: sx, b: 0, c: 0, d: -sy, tx: 0, ty: ah + imgH * sy)
                     : CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: ah - imgH * (1 - f) * sy)
        return band.transformed(by: t).cropped(to: skyRect)
    }

    var sky: CIImage
    if case .wholeScreen = style.source {
        // 그림을 화면 전체에 꽉 차게(가운데 기준) 키워 흐린다.
        let sc = max(ww / imgW, hh / imgH)
        let cover = src.transformed(by: CGAffineTransform(scaleX: sc, y: sc))
            .transformed(by: CGAffineTransform(translationX: (ww - imgW * sc) / 2, y: (hh - imgH * sc) / 2))
        sky = blur(cover, style.near)
    } else {
        // ① 재료
        var mat: CIImage
        switch style.source {
        case let .top(f, flip):
            mat = topBand(f, flip: flip)
        case let .patch(r):
            let pr = ciRect(r)
            let c = max(ww / pr.width, sh / pr.height)
            mat = src.cropped(to: pr)
                .transformed(by: CGAffineTransform(translationX: -pr.minX, y: -pr.minY))
                .transformed(by: CGAffineTransform(scaleX: c, y: c))
                .transformed(by: CGAffineTransform(translationX: (ww - pr.width * c) / 2, y: ah + (sh - pr.height * c) / 2))
                .cropped(to: skyRect)
        case .wholeScreen:
            return nil   // 위에서 처리
        }
        // ①′ 얹을 조각: 가장자리를 타원으로 부드럽게(안쪽 55% 는 그대로) 따서 빈 하늘의 center 에 폭 width 로
        if let o = style.overlay {
            let pr = ciRect(o.patch)
            let cw = o.width * ww, ch = cw * pr.height / pr.width
            let cx = o.center.x * ww, cy = hh - o.center.y * sh
            let piece = src.cropped(to: pr)
                .transformed(by: CGAffineTransform(translationX: -pr.minX, y: -pr.minY))
                .transformed(by: CGAffineTransform(scaleX: cw / pr.width, y: cw / pr.width))
                .transformed(by: CGAffineTransform(translationX: cx - cw / 2, y: cy - ch / 2))
            if let disc = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": CIVector(x: 0, y: 0), "inputRadius0": 0.55, "inputRadius1": 1.0,
                "inputColor0": CIColor(red: 1, green: 1, blue: 1), "inputColor1": CIColor(red: 0, green: 0, blue: 0),
            ])?.outputImage {
                let mask = disc.transformed(by: CGAffineTransform(scaleX: cw / 2, y: ch / 2))
                    .transformed(by: CGAffineTransform(translationX: cx, y: cy)).cropped(to: skyRect)
                mat = piece.applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputBackgroundImageKey: mat, kCIInputMaskImageKey: mask]).cropped(to: skyRect)
            }
        }
        // ② 아래 절반(이음매 쪽)을 180° 돌려 위 절반에: (x, y) → (ww − x, 2·ah + sh − y)
        if style.echo {
            let lower = mat.cropped(to: CGRect(x: 0, y: ah, width: ww, height: sh / 2))
            let upper = lower.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: ww, ty: 2 * ah + sh))
            mat = upper.composited(over: lower).cropped(to: skyRect)
        }
        // ③ 90° 돌려 다시 빈 하늘 크기로(가로세로 비율은 늘여 맞춘다). Core Image 는 위가 +y 라 시계 방향이 −90°.
        if style.turn != 0 {
            let r = mat.transformed(by: CGAffineTransform(translationX: 0, y: -ah))
                .transformed(by: CGAffineTransform(rotationAngle: style.turn > 0 ? -.pi / 2 : .pi / 2))
            let e = r.extent
            mat = r.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
                .transformed(by: CGAffineTransform(scaleX: ww / e.width, y: sh / e.height))
                .transformed(by: CGAffineTransform(translationX: 0, y: ah))
                .cropped(to: skyRect)
        }
        // ④ 이음매 위 seam 만큼은 '뒤집은 그림 위 15%'(그림 윗줄과 정확히 이어짐)로 섞는다.
        if style.seam > 0, let m = ramp(black: CGPoint(x: 0, y: ah + sh * style.seam), white: CGPoint(x: 0, y: ah)) {
            mat = topBand(0.15, flip: true).applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: mat, kCIInputMaskImageKey: m]).cropped(to: skyRect)
        }
        // ⑤ 아래는 그림 그대로 둬야 이음매 근처 흐림이 그림 색을 끌어온다(빈 곳의 검정·투명이 번져 들지 않게).
        let ext = mat.composited(over: artPlaced)
        guard let mask = ramp(black: CGPoint(x: 0, y: hh), white: CGPoint(x: 0, y: ah)) else { return nil }
        sky = blur(ext, style.near).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: blur(ext, style.far), kCIInputMaskImageKey: mask])   // 이음매(흰색) near → 맨 위(검정) far
    }
    // 맨 아래 band: 그림 윗변(ah)에서 불투명 → band 아래 끝에서 투명
    guard let fade = ramp(black: CGPoint(x: 0, y: ah - bandPx), white: CGPoint(x: 0, y: ah)) else { return nil }
    sky = sky.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: fade])
    let out = CGRect(x: 0, y: (ah - bandPx).rounded(.down), width: ww, height: hh - (ah - bandPx).rounded(.down))
    return skyContext.createCGImage(sky, from: out, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
}

/// 2026-11-20 (#34) 오너: 밤 장면 위쪽은 "밤과 그 안의 작은 별" — 별을 하나씩 흩뿌린다.
/// 오너 3차: "별들이 블러처리되어야 하고, 조금 더 랜덤하게, 크기도 조금씩 다 다르게, 블러 강도도 다르게."
///   (그 전엔 그림 조각의 잔결을 칸마다 뒤집어 붙였는데, 별이 다 또렷하고 같은 무늬가 되풀이됐다.)
/// - 자리: 균일 무작위(뭉치고 비는 곳이 자연스럽게 생긴다) · 크기(핵 σ): 로그정규 · 흐림 σ: 균일 · 밝기: 균일.
///   흐린 별은 빛이 퍼진 만큼 가운데가 어두워진다(밝기 × (핵 σ / 전체 σ)²).
/// - 색 · 양은 그림 속 별에서 쟀다: 밤 오른쪽 위 조각(461×245px)에 별 25개, 밝은 별 평균색 (211, 219, 220).
///   양은 그 절반(9:16 시안에서 0.30 은 빽빽했다) — pt² 당 0.0006개.
/// - size: 레이어 크기(pt, 그림 윗변부터 화면 맨 위까지) · scale: 화면 배율 · fadeBand: 이음매 위 이 높이(pt)에서 별이 0 → 1
/// - clear: 별을 두지 않을 자리(pt, 레이어 좌표 — 제목·안내 글자. 글자 옆 별이 따옴표처럼 읽혔다)
/// 고정 씨앗이라 같은 화면 크기면 매번 같다. 🔒 실패하면 nil — 별 없이 흐린 하늘만 나온다.
func makeStarLayer(size: CGSize, scale: CGFloat, fadeBand: CGFloat, clear: CGRect?) -> CGImage? {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let W = Int((size.width * scale).rounded()), H = Int((size.height * scale).rounded())
    guard W > 0, H > 0, let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    // 가우스 모양 빛(반지름 3σ 까지): t = r / 3σ 에서 알파 exp(−4.5 t²)
    let ts: [CGFloat] = [0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1]
    let colors = ts.map { CGColor(srgbRed: 211 / 255, green: 219 / 255, blue: 220 / 255, alpha: exp(-4.5 * $0 * $0)) }
    guard let glow = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: ts) else { return nil }
    var seed: UInt64 = 7
    func unit() -> CGFloat {   // SplitMix64 → [0, 1)
        seed &+= 0x9E37_79B9_7F4A_7C15
        var z = seed
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat((z ^ (z >> 31)) >> 11) / CGFloat(1 << 53)
    }
    func gauss() -> CGFloat { sqrt(-2 * log(max(1e-9, unit()))) * cos(2 * .pi * unit()) }
    let count = Int(size.width * size.height * 0.0006)
    for _ in 0..<count {
        let x = unit() * size.width, y = unit() * size.height      // pt, 아래(이음매)가 0
        let core = exp(log(0.55) + 0.45 * gauss())                   // 핵 σ (pt)
        let soft = 0.3 + unit() * 1.9                                // 흐림 σ (pt)
        let sigma = (core * core + soft * soft).squareRoot()
        var peak = min(1, (0.35 + unit() * 0.65) * (core / sigma) * (core / sigma) * 1.6)
        peak *= min(1, y / max(1, fadeBand))
        let reach = 3 * sigma
        if peak < 0.02 { continue }
        if let c = clear, c.insetBy(dx: -reach, dy: -reach).contains(CGPoint(x: x, y: y)) { continue }
        let p = CGPoint(x: x * scale, y: y * scale)
        ctx.saveGState()
        ctx.setAlpha(peak)
        ctx.drawRadialGradient(glow, startCenter: p, startRadius: 0, endCenter: p, endRadius: reach * scale, options: [])
        ctx.restoreGState()
    }
    return ctx.makeImage()
}
