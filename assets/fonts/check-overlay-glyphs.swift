// 청소 화면 글자 검사 — 2026-11-18 (#25)
//
// 청소 화면(오버레이)의 문구 4개(cleaning · mouseHint · done · shortcutHint)를 Sources/ddaka/main.swift 에서 읽어,
// 언어마다 그 언어 글꼴(assets/fonts 의 서브셋)에 모든 글자가 있는지 본다. 하나라도 빠지면 1 로 끝난다 → build.sh 가 멈춘다.
// 왜: 서브셋은 앱이 쓰는 글자만 남긴 글꼴이다. 문구를 고쳤는데 서브셋을 다시 안 만들면, 빠진 글자만 맥 글꼴로 섞여 보인다
//     (깨지지는 않아서 눈으로는 놓치기 쉽다). 비교 시안에서 粉圓 간체가 실제로 그랬다(键盘标 3자).
//
// 쓰는 법
//   swift assets/fonts/check-overlay-glyphs.swift <main.swift> <글꼴 폴더>            → 검사
//   swift assets/fonts/check-overlay-glyphs.swift <main.swift> --print <ja|zh-Hans|zh-Hant|ko|en>  → 그 언어 문구의 글자(중복 없이)
//
// 🔒 언어 ↔ 글꼴 짝은 Themes.swift 의 overlayFont 와 같아야 한다. 한쪽만 바꾸면 이 검사가 엉뚱한 글꼴을 본다.
// "⌘⇧9" 는 빼고 본다 — 앱이 그 세 글자만 Apple SD Gothic Neo 로 그린다(shortcutAttributed).
import CoreText
import Foundation

let langs = ["en", "ko", "ja", "zh-Hans", "zh-Hant"]   // main.swift 의 L(en, ko, ja, zhHans, zhHant) 순서
let fontFor = [
    "en": "GowunDodum-Regular.ttf",
    "ko": "GowunDodum-Regular.ttf",
    "ja": "KleeOne-Regular.ttf",
    "zh-Hans": "DdakaKaiSC-Regular.ttf",
    "zh-Hant": "LXGWWenKaiTC-Regular.ttf",
]
// 앱이 NSFont(name:) 으로 찾는 PostScript 이름 — 파일은 맞는데 이름이 다르면 앱은 조용히 예비 글꼴로 물러난다(2026-11-18 리뷰).
let postScriptNameFor = [
    "GowunDodum-Regular.ttf": "GowunDodum-Regular",
    "KleeOne-Regular.ttf": "KleeOne-Regular",
    "DdakaKaiSC-Regular.ttf": "DdakaKaiSC-Regular",
    "LXGWWenKaiTC-Regular.ttf": "LXGWWenKaiTC-Regular",
]
let keys = ["cleaning", "mouseHint", "done", "shortcutHint"]   // 🔒 main.swift 「오버레이 화면」 주석과 짝

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(("❌ " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 3, let source = try? String(contentsOfFile: args[1], encoding: .utf8) else {
    fail("쓰는 법: swift check-overlay-glyphs.swift <main.swift> <글꼴 폴더 | --print 언어>")
}

/// `static let <key> = L(` 뒤의 문자열 5개를 읽는다. 따옴표 안의 \" 와 \\ 만 풀어 준다.
/// 그 밖의 이스케이프(\u{…} · \( … ) 등)는 글자를 잘못 읽어 "통과했는데 실제론 다른" 결과가 나오므로 실패로 끝낸다(2026-11-18 리뷰).
func strings(for key: String) -> [String] {
    guard let start = source.range(of: "static let \(key) = L(") else { fail("main.swift 에서 \(key) = L( 를 못 찾았어") }
    var out: [String] = []
    var i = start.upperBound
    while out.count < 5 {
        guard let open = source[i...].firstIndex(of: "\"") else { fail("\(key) 의 문자열이 5개가 안 돼") }
        var s = "", j = source.index(after: open), escaped = false
        while true {
            guard j < source.endIndex else { fail("\(key) 의 문자열이 닫히지 않았어") }
            let ch = source[j]
            if escaped {
                guard ch == "\"" || ch == "\\" else {
                    fail("\(key) 문자열에 이 검사가 읽지 못하는 이스케이프(\\\(ch))가 있어 — 청소 화면 문구는 글자를 직접 적어 줘")
                }
                s.append(ch); escaped = false
            }
            else if ch == "\\" { escaped = true }
            else if ch == "\"" { break }
            else { s.append(ch) }
            j = source.index(after: j)
        }
        out.append(s)
        i = source.index(after: j)
    }
    return out
}

var textByLang: [String: String] = [:]
for key in keys {
    for (n, s) in strings(for: key).enumerated() {
        textByLang[langs[n], default: ""] += s.replacingOccurrences(of: "⌘⇧9", with: "")
    }
}
func uniqueChars(_ s: String) -> [Character] {
    var seen = Set<Character>(), out: [Character] = []
    for c in s where !seen.contains(c) { seen.insert(c); out.append(c) }
    return out
}

if args[2] == "--print" {
    guard args.count >= 4, let text = textByLang[args[3]] else { fail("--print 뒤에 언어(\(langs.joined(separator: "|")))") }
    print(String(uniqueChars(text)))
    exit(0)
}

let fontDir = URL(fileURLWithPath: args[2])
var problems = 0
for lang in langs {
    let file = fontFor[lang]!
    let url = fontDir.appendingPathComponent(file)
    guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor], let desc = descs.first else {
        fail("\(file) 를 글꼴로 읽지 못했어")
    }
    let font = CTFontCreateWithFontDescriptor(desc, 20, nil)
    let psName = CTFontCopyPostScriptName(font) as String
    if psName != postScriptNameFor[file] {
        problems += 1
        print("❌ \(lang): \(file) 의 PostScript 이름이 \(psName) — 앱(Themes.swift overlayFont)은 \(postScriptNameFor[file] ?? "?") 으로 찾는다")
    }
    var missing: [Character] = []
    for c in uniqueChars(textByLang[lang] ?? "") {
        var units = Array(String(c).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        if !CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count) { missing.append(c) }
    }
    if missing.isEmpty {
        print("   \(lang): \(file) — 글자 \(uniqueChars(textByLang[lang] ?? "").count)개 모두 있음 ✓")
    } else {
        problems += 1
        print("❌ \(lang): \(file) 에 없는 글자 \(missing.count)개: \(String(missing))")
    }
}
if problems > 0 {
    fail("청소 화면 글꼴 검사 실패 — 위 ❌ 줄을 봐 줘. 글자가 빠졌으면 assets/fonts/make-subsets.sh 로 서브셋을 다시 만들고, 이름이 다르면 Themes.swift 와 맞춰 줘 (assets/fonts/README.md)")
}
