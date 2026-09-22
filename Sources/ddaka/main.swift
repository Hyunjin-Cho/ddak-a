import Cocoa
import ApplicationServices
import IOKit.hid

// 🚨 2026-08-12 오너 결정: 청소 시간을 5분 → 3분으로 확정.
// 이전에는 화면에 "05:00"이 표시되는데 테스트용 안전장치가 60초에 앱을 꺼버려서
// "표시된 시간과 실제 동작이 다른" 상태였다. 세 값을 한 줄로 정렬해 그 불일치를 없앤다.
let totalSeconds = 180 // 화면에 표시되는 청소 시간 (3분)
let safetyLimitSeconds: TimeInterval = 190 // 카운트다운보다 10초 길게 — 정상 동작은 방해하지 않으면서 최후의 보루로 남는다
let hardKillGraceSeconds: TimeInterval = 5 // 세이프티 타이머마저 실패했을 때 프로세스를 강제 종료하기까지의 여유 (총 195초)

// MARK: - 다국어 (2026-08-12: 영어 기본 / 한국어 / 일본어 / 중국어)
// 🚨 2026-09-22: 중국어를 간체(zhHans)와 번체(zhHant)로 나눴다. 종전에는 zh 로 시작하면
// 전부 간체로 보냈기 때문에 대만·홍콩 사용자가 어색한 표기를 봤다(리뷰 F-8).
// 이 4개(실질 5종) 밖의 언어는 전부 영어로 떨어진다 — 독일어·프랑스어 등은 영어를 본다.

enum UILanguage { case en, ko, ja, zhHans, zhHant }

// 번들에 .lproj 리소스를 넣지 않고 시스템 선호 언어를 직접 읽는다.
// (SPM 실행 타겟 + 수동 .app 패키징 구조라 표준 로컬라이제이션 리소스를 쓰기 번거롭고,
//  문자열이 십수 개뿐이라 코드에서 관리하는 편이 오히려 한눈에 들어온다.)
let uiLanguage: UILanguage = {
    // 🚨 2026-09-22: Locale.preferredLanguages -> Bundle.main.preferredLocalizations 로 교체.
    // 앞의 것은 시스템 선호 언어 목록을 "그대로" 돌려준다. 그 첫 번째만 보므로 1순위가 우리가
    // 지원하지 않는 언어면 2순위에 한국어가 있어도 영어로 떨어졌다
    // (실측: fr-FR, ko-KR, en-US 사용자가 영어를 봤다).
    // 뒤의 것은 Info.plist 의 CFBundleLocalizations 와 교집합을 내서 "우리가 실제로 보여줄 수
    // 있는 것 중 사용자가 가장 원하는 것"을 돌려준다.
    //
    // 🔒 Info.plist 의 CFBundleLocalizations 와 반드시 짝으로 움직인다. 이쪽만 바꾸고 그 목록을
    // 빠뜨리면 preferredLocalizations 가 en 하나만 들고 있어서 **모든 사용자가 영어로 떨어진다**
    // (실측 2026-09-22: 목록을 뺀 번들에서는 선호 언어가 ko-KR 하나여도 en 이 나왔다).
    //
    // 돌아오는 값은 선언한 대로 en/ko/ja/zh-Hans/zh-Hant 로 딱 떨어지지만, 아래 hasPrefix 분기는
    // 그대로 둔다 — 번들 Info.plist 없이 도는 경우(swift run 등)엔 시스템 표기가 그대로 올 수 있다.
    guard let code = Bundle.main.preferredLocalizations.first?.lowercased() else { return .en }
    if code.hasPrefix("ko") { return .ko }
    if code.hasPrefix("ja") { return .ja }
    if code.hasPrefix("zh") {
        // 대만·홍콩·마카오는 번체. 표기는 zh-hant-tw 처럼 오기도 하고 zh-tw 처럼 짧게 오기도 한다.
        // 싱가포르(zh-hans-sg)와 본토(zh-hans-cn)는 간체이므로 아래 목록에 넣지 않는다.
        for hant in ["zh-hant", "zh-tw", "zh-hk", "zh-mo"] where code.hasPrefix(hant) {
            return .zhHant
        }
        return .zhHans
    }
    return .en
}()

func L(_ en: String, _ ko: String, _ ja: String, _ zhHans: String, _ zhHant: String) -> String {
    switch uiLanguage {
    case .en: return en
    case .ko: return ko
    case .ja: return ja
    case .zhHans: return zhHans
    case .zhHant: return zhHant
    }
}

enum Strings {
    static let totalMinutes = totalSeconds / 60

    // 실행 확인
    static let confirmTitle = L(
        "Start ddak-a?",
        "닦아 실행할까요?",
        "ddak-a を開始しますか？",
        "要启动 ddak-a 吗？",
        "要啟動 ddak-a 嗎？"
    )
    static let confirmBody = L(
        "Your screen will be covered in sky blue and every keystroke will be blocked for \(totalMinutes) minutes — or until you click “Done”. Your mouse and trackpad keep working.\n\nYou can quit at any time with ⌘⇧9.",
        "실행하면 화면이 하늘색으로 덮이고, 키보드 입력이 \(totalMinutes)분간(또는 '다 닦았어요' 버튼을 누를 때까지) 완전히 차단돼요. 마우스·트랙패드는 그대로 움직여요.\n\n언제든 ⌘⇧9 을 누르면 바로 종료돼요.",
        "画面が水色で覆われ、キーボード入力が\(totalMinutes)分間（または「完了」ボタンを押すまで）完全にブロックされます。マウス・トラックパッドはそのまま使えます。\n\n⌘⇧9 でいつでも終了できます。",
        "屏幕将被天蓝色覆盖，键盘输入将被完全阻止 \(totalMinutes) 分钟（或直到您点击“完成”按钮）。鼠标和触控板仍可正常使用。\n\n随时按 ⌘⇧9 即可退出。",
        "螢幕將被天藍色覆蓋，鍵盤輸入將被完全阻擋 \(totalMinutes) 分鐘（或直到您點擊「完成」按鈕）。滑鼠和觸控板仍可正常使用。\n\n隨時按 ⌘⇧9 即可結束。"
    )
    static let confirmStart = L("Start", "예", "開始", "开始", "開始")
    // 🚨 2026-09-23 (#8): "아니오" -> "아니요". 대답하는 말은 '아니요'가 표준이다('아니오'는
    // "그것은 사과가 아니오"처럼 문장을 끝맺는 말). macOS 자체 대화상자도 '아니요'를 쓴다.
    static let confirmCancel = L("Cancel", "아니요", "キャンセル", "取消", "取消")

    // 임시 경로(App Translocation) 안내
    // 🚨 2026-09-22 신설. 문구는 "무엇을 하면 되는지"만 말한다 — translocation 이 무엇인지
    // 설명해 봐야 읽히지 않는다. 원인 설명은 개발자 몫이고, 사용자에게 필요한 건 다음 동작 하나다.
    static let translocatedTitle = L(
        "Move ddak-a to your Applications folder",
        "‘응용 프로그램’ 폴더로 옮겨 주세요",
        "「アプリケーション」フォルダに移動してください",
        "请将 ddak-a 移到“应用程序”文件夹",
        "請將 ddak-a 移到「應用程式」檔案夾"
    )
    // 🚨 2026-09-22 (PR #1 리뷰 F-5): 마지막 문단에 "확인 -> 종료 -> 옮기기" 순서를 명시한다.
    // 종전 문구는 "옮긴 뒤 거기서 실행해 주세요"까지만 말했는데, 이 안내창은 모달이라
    // 확인을 누르기 전까지 앱이 살아 있다. 그 상태에서 시키는 대로 앱을 옮겨 실행하면
    // LSMultipleInstancesProhibited(=true) 때문에 새 인스턴스가 막히고 임시 사본이 앞으로
    // 나와 같은 안내를 다시 보여 줄 수 있다 — 안내가 시킨 동작이 그대로 함정이 된다.
    // ⚠️ 그 반복 자체는 아직 재현하지 못했다(리뷰 F-5 는 needs_check). 다만 "확인 -> 종료"가
    //    실제 순서이므로, 재현 여부와 무관하게 이 문구가 더 정확하다.
    // 🔒 "확인"은 Strings.ok 의 각 언어 표기와 같아야 한다(en OK / ko 확인 / ja OK / zh 好).
    static let translocatedBody = L(
        "macOS is running ddak-a from a temporary copy. In this state, Accessibility and Input Monitoring stay off no matter how many times you turn them on.\n\nClick OK to quit ddak-a. Then drag ddak-a into the Applications folder in Finder and open it from there.",
        "지금 닦아가 임시 복사본에서 실행되고 있어요. 이 상태에서는 손쉬운 사용·입력 모니터링을 아무리 켜도 계속 꺼진 채로 남아요.\n\n‘확인’을 누르면 닦아가 종료돼요. 그다음 Finder 에서 닦아를 ‘응용 프로그램’ 폴더로 끌어다 놓고, 거기서 실행해 주세요.",
        "macOS が ddak-a を一時的なコピーから実行しています。この状態では、アクセシビリティと入力監視を何度オンにしてもオフのままになります。\n\n「OK」を押すと ddak-a が終了します。その後、Finder で ddak-a を「アプリケーション」フォルダにドラッグして、そこから起動してください。",
        "macOS 正在从临时副本运行 ddak-a。在这种状态下，无论开启多少次辅助功能和输入监控，它们都会保持关闭。\n\n点击“好”后 ddak-a 会退出。然后请在访达中将 ddak-a 拖到“应用程序”文件夹，并从那里启动。",
        "macOS 正從暫存副本執行 ddak-a。在這種狀態下，無論開啟多少次輔助使用和輸入監控，都會維持關閉。\n\n按「好」後 ddak-a 會結束。接著請在 Finder 中將 ddak-a 拖到「應用程式」檔案夾，並從那裡啟動。"
    )

    // 권한 안내
    static let permissionTitle = L(
        "Additional permissions needed",
        "권한이 더 필요해요",
        "追加の権限が必要です",
        "需要额外权限",
        "需要額外權限"
    )
    // 🚨 2026-09-23 (#8): 한국어 문구는 전부 해요체로 맞춘다. 이 문구만 "켜줘"(반말)로 시작해
    // 한 메시지 안에서 반말과 해요체("돼요")가 섞여 있었다. 탭 실패 안내(tapFailedBody)도 같은 문제.
    static func permissionBody(_ list: String) -> String {
        return L(
            "Open System Settings › Privacy & Security and turn on ddak-a for:\n\n\(list)\n\nThen launch ddak-a again.",
            "시스템 설정 > 개인정보 보호 및 보안에서 아래 항목의 '닦아(ddak-a)'를 켜 주세요.\n\n\(list)\n\n켠 다음 닦아를 다시 실행하면 돼요.",
            "「システム設定 › プライバシーとセキュリティ」で、以下の項目の ddak-a をオンにしてください。\n\n\(list)\n\nオンにしたら ddak-a をもう一度起動してください。",
            "请在“系统设置 › 隐私与安全性”中为以下项目启用 ddak-a：\n\n\(list)\n\n启用后请重新启动 ddak-a。",
            "請在「系統設定 › 隱私權與安全性」中為以下項目啟用 ddak-a：\n\n\(list)\n\n啟用後請重新啟動 ddak-a。"
        )
    }
    static let permissionAccessibility = L(
        "• Accessibility",
        "• 손쉬운 사용 (Accessibility)",
        "• アクセシビリティ",
        "• 辅助功能",
        "• 輔助使用"
    )
    static let permissionInputMonitoring = L(
        "• Input Monitoring",
        "• 입력 모니터링 (Input Monitoring)",
        "• 入力監視",
        "• 输入监控",
        "• 輸入監控"
    )
    static let openInputMonitoring = L(
        "Open Input Monitoring",
        "입력 모니터링 열기",
        "入力監視を開く",
        "打开输入监控",
        "打開輸入監控"
    )
    static let openAccessibility = L(
        "Open Accessibility",
        "손쉬운 사용 열기",
        "アクセシビリティを開く",
        "打开辅助功能",
        "打開輔助使用"
    )
    static let close = L("Close", "닫기", "閉じる", "关闭", "關閉")

    // 이벤트탭 실패
    static let tapFailedTitle = L(
        "Couldn’t block the keyboard",
        "키보드를 막지 못했어요",
        "キーボードをブロックできませんでした",
        "无法阻止键盘输入",
        "無法阻擋鍵盤輸入"
    )
    static let tapFailedBody = L(
        "Turn on both Accessibility and Input Monitoring for ddak-a in System Settings › Privacy & Security, then launch it again.",
        "시스템 설정 > 개인정보 보호 및 보안에서 손쉬운 사용과 입력 모니터링 둘 다 '닦아'를 켠 다음 다시 실행해 주세요.",
        "「システム設定 › プライバシーとセキュリティ」でアクセシビリティと入力監視の両方をオンにしてから、もう一度起動してください。",
        "请在“系统设置 › 隐私与安全性”中同时启用辅助功能和输入监控，然后重新启动。",
        "請在「系統設定 › 隱私權與安全性」中同時啟用輔助使用和輸入監控，然後重新啟動。"
    )
    static let ok = L("OK", "확인", "OK", "好", "好")

    // 오버레이 화면
    // 🚨 2026-09-23 (#8): "청소중" -> "청소 중". '중'은 의존 명사라 띄어 쓴다.
    static let cleaning = L(
        "Cleaning keyboard",
        "키보드 청소 중",
        "キーボード清掃中",
        "正在清洁键盘",
        "正在清潔鍵盤"
    )
    static let mouseHint = L(
        "Your mouse and trackpad still work",
        "마우스·트랙패드는 자유롭게 움직여도 돼요",
        "マウス・トラックパッドはそのまま使えます",
        "鼠标和触控板仍可正常使用",
        "滑鼠和觸控板仍可正常使用"
    )
    static let done = L("Done", "다 닦았어요", "完了", "完成", "完成")
    // 🚨 2026-08-12: 갇혔을 때 화면에 탈출 방법이 보이지 않으면 안전장치로서 의미가 없다
    static let shortcutHint = L(
        "Press ⌘⇧9 to quit right away",
        "⌘⇧9 을 누르면 바로 종료돼요",
        "⌘⇧9 でいつでも終了できます",
        "按 ⌘⇧9 可立即退出",
        "按 ⌘⇧9 可立即結束"
    )
}

// 2026-08-12 최적화: 0.6초마다 문자열을 새로 조립하지 않도록 상태를 미리 만들어 둔다
// 🚨 2026-09-22 오너 요청: 점이 3개까지 늘던 것을 5개까지로 바꿨다(상태 6가지).
// dotCount 는 이 배열 길이로 나머지 연산을 하므로 개수를 여기서만 바꾸면 된다.
// 한 바퀴는 1초 x 6 = 6초다.
let maxCleaningDots = 5
let cleaningTitles: [String] = {
    let base = Strings.cleaning
    return (0...maxCleaningDots).map { base + String(repeating: ".", count: $0) }
}()

// 2026-08-12 최적화: 색·폰트·문구는 모니터 수만큼 다시 만들 이유가 없어 한 번만 만들어 공유한다
let skyBlueColor = NSColor(calibratedRed: 0.53, green: 0.81, blue: 0.92, alpha: 1.0)
let buttonNormalColor = NSColor.white.cgColor
// 2026-08-12: 눌림은 색이 아니라 "그림자가 줄며 가라앉는 것"으로 표현한다.
// 배경색은 아주 살짝만 낮춰 거드는 정도 — 크게 어둡게 하면 눌린 게 아니라 색이 변한 것처럼 보인다.
let buttonPressedColor = NSColor(calibratedWhite: 0.96, alpha: 1.0).cgColor
let buttonShadowOpacityResting: Float = 0.22
let buttonShadowOpacityPressed: Float = 0.07
// 🚨 2026-08-12: 테두리가 없으면 눌렸을 때 "면이 어두워진다"가 아니라 "덩어리 색이 변한다"로 보인다.
// 경계선이 있어야 그 안쪽이 눌려 들어가는 것으로 읽힌다. 글자와 같은 계열의 옅은 남색.
let buttonBorderColorResting = NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.5, alpha: 0.22).cgColor
let buttonBorderColorPressed = NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.5, alpha: 0.48).cgColor
let titleFont = NSFont.systemFont(ofSize: 48, weight: .semibold)
let subLabelFont = NSFont.systemFont(ofSize: 16, weight: .regular)
let countdownFont = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .regular)
let buttonAttributedTitle = NSAttributedString(
    string: Strings.done,
    attributes: [
        .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.5, alpha: 1.0),
        .font: NSFont.systemFont(ofSize: 18, weight: .medium)
    ]
)

// 2026-08-12 최적화: 이벤트탭 콜백은 키 입력마다 실행되고, 느리면 macOS가 탭을 강제로 끊는다
// (= 키보드가 순간 뚫림). 콜백 안에서는 힙 할당이 생기지 않도록 상수만 쓰고 switch로 비교한다.
// 🚨 2026-08-12 변경: 탈출 단축키를 Cmd+Option+Esc → Cmd+Shift+9로 교체.
// (1) Cmd+Option+Esc는 macOS 강제 종료 창을 띄우는 시스템 단축키였는데, 우리 오버레이가
//     최상위 레벨이라 그 창이 뒤에 가려 보이지 않았다 = 보이지 않는 탈출구.
//     이제는 통과시키지 않고 앱이 직접 조합을 감지해 스스로 종료한다(다른 앱으로 새지도 않는다).
// (2) 처음엔 Cmd+Shift+1을 썼으나 Cmd·Shift·1이 전부 키보드 왼쪽에 몰려 있어, 걸레로 그 구역을
//     문지르면 한 손에 동시에 눌릴 수 있다는 오너 지적으로 9로 변경.
//     9는 오른쪽 위라 물리적으로 양손을 써야만 발동한다 = 우연 발동 확률이 크게 낮아진다.
private let kVKANSI9: Int64 = 25 // 숫자 9
private let kVKCapsLock: Int64 = 57
private let nxSysDefinedEventType: UInt32 = 14 // NX_SYSDEFINED
private let nxSubtypeAuxControlButtons: Int16 = 8 // 밝기·볼륨 등 미디어 키가 실려 오는 subtype

// 🚨 2026-08-12: NSWindow는 기본적으로 창을 "화면 안쪽"으로 끌어당기고(constrainFrameRect),
// borderless 창은 키 윈도우가 될 수 없다. 전체화면 오버레이에서는 둘 다 방해가 되므로 무력화한다.
// (이전 버전에서 보조 모니터 창이 메인 쪽으로 끌려와 한쪽만 덮이던 버그의 원인 후보)
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

// 🚨 2026-08-12: 앱이 활성 상태가 아닐 때 첫 클릭이 "창 활성화"로만 소비되면 탈출 버튼이 안 눌린다.
// 키보드가 막힌 상태에서 유일한 탈출구이므로 첫 클릭부터 반드시 먹혀야 한다.
final class OverlayButton: NSButton {
    // 2026-09-22: 눌림 모양에서도 같은 비율을 써야 해서 기억해 둔다
    private var cornerScale: CGFloat = 1.0

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // 2026-08-12: 평상시 모양. frame을 정한 뒤에 불러야 한다(shadowPath가 bounds를 쓰므로).
    // 흰 배경만 깔면 "평평한 사각형"이라 눌러도 눌린 느낌이 안 난다 → 그림자로 살짝 띄운다.
    // 2026-09-22: scale 은 작은 화면에서 배치가 줄어든 비율. 모서리와 그림자만 원래 크기로
    // 남으면 버튼이 뭉툭해 보여서 함께 줄인다.
    func applyRestingStyle(scale: CGFloat = 1.0) {
        wantsLayer = true
        guard let layer = layer else { return }
        cornerScale = scale
        layer.backgroundColor = buttonNormalColor
        layer.cornerRadius = 10 * scale
        layer.borderWidth = 1
        layer.borderColor = buttonBorderColorResting
        layer.masksToBounds = false // 그림자가 잘리지 않게
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = buttonShadowOpacityResting
        layer.shadowRadius = 8 * scale
        layer.shadowOffset = CGSize(width: 0, height: -3 * scale) // macOS는 y가 위쪽이 + → 음수가 아래
        // 경로를 직접 주면 매 프레임 알파를 훑어 그림자를 계산하지 않는다(그리기 비용 절감)
        layer.shadowPath = CGPath(roundedRect: bounds, cornerWidth: 10 * scale,
                                  cornerHeight: 10 * scale, transform: nil)
    }

    // 2026-08-12 추가: isBordered = false + 커스텀 배경이라 시스템 기본 눌림 효과가 없다.
    // super.mouseDown은 마우스를 뗄 때까지 안에서 트래킹하므로, 그 앞뒤를 감싸면
    // "누르고 있는 동안"만 정확히 눌린 모양으로 만들 수 있다.
    override func mouseDown(with event: NSEvent) {
        setPressedLook(true)
        super.mouseDown(with: event)
        setPressedLook(false)
    }

    private func setPressedLook(_ pressed: Bool) {
        // 암묵적 애니메이션을 끄고 즉시 반영 — 눌림 피드백은 늦게 오면 의미가 없다
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.backgroundColor = pressed ? buttonPressedColor : buttonNormalColor
        layer?.borderColor = pressed ? buttonBorderColorPressed : buttonBorderColorResting
        layer?.shadowOpacity = pressed ? buttonShadowOpacityPressed : buttonShadowOpacityResting
        layer?.shadowRadius = (pressed ? 3 : 8) * cornerScale
        layer?.shadowOffset = CGSize(width: 0, height: (pressed ? -1 : -3) * cornerScale)
        CATransaction.commit()
    }
}

// MARK: - 임시 경로(App Translocation) 감지
//
// 🚨 2026-09-22 신설. 브라우저로 받은 앱을 Finder 로 끌어다 옮기지 않고 그대로 실행하면,
// macOS 가 원본 대신 /private/var/folders/.../AppTranslocation/<UUID>/d/ 의 읽기 전용 사본을
// 띄운다(Gatekeeper 경로 무작위화). 이 상태에서는 손쉬운 사용·입력 모니터링 권한을 켜도
// 다음 실행 때 다시 꺼져 있다 — 사용자에게는 "권한을 켰는데 앱이 계속 없다고 한다"로 보인다.
// 실측(2026-09-22): 공증·티켓 부착까지 끝낸 v1.0 을 브라우저로 받아 설치했더니
// com.apple.quarantine 이 번들 안팎 10곳에 남아 있었다. 공증은 quarantine 을 지우지 않는다.
//
// 판정을 두 갈래로 두는 이유: 애플의 정답은 SecTranslocateIsTranslocatedURL 인데 이 함수는
// SDK 에 공개 헤더가 없어 Swift 에서 바로 부를 수 없다(실측 2026-09-22: Security 모듈에 없고
// 런타임 심볼은 존재). 그래서 dlsym 으로 찾아 쓰되, 못 찾거나 호출이 실패하면 경로 성분으로
// 떨어진다. 경로 규약도 문서화된 것이 아니라서 어느 한쪽만으로는 조용히 미탐이 될 수 있다.
private func isRunningFromTemporaryCopy() -> Bool {
    let bundleURL = Bundle.main.bundleURL

    typealias IsTranslocatedFn = @convention(c) (
        CFURL, UnsafeMutablePointer<DarwinBoolean>, UnsafeMutablePointer<Unmanaged<CFError>?>?
    ) -> DarwinBoolean

    // -2 = RTLD_DEFAULT. 이미 로드된 이미지 전체에서 심볼을 찾는다.
    if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "SecTranslocateIsTranslocatedURL") {
        let isTranslocated = unsafeBitCast(symbol, to: IsTranslocatedFn.self)
        var flag: DarwinBoolean = false
        var error: Unmanaged<CFError>?
        let callSucceeded = isTranslocated(bundleURL as CFURL, &flag, &error).boolValue
        error?.release() // 실패 시 +1 로 돌아오는 오류 객체를 흘리지 않는다
        if callSucceeded { return flag.boolValue }
    }

    return bundleURL.pathComponents.contains("AppTranslocation")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindows: [NSWindow] = []
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var dotTimer: Timer?
    var countdownTimer: Timer?
    var safetyTimer: Timer?
    var remainingSeconds = totalSeconds
    var dotCount = 0
    var isCleaning = false
    var isFinishing = false
    var lastCountdownText = "" // 2026-08-12 최적화: 값이 안 바뀌었으면 화면을 다시 그리지 않기 위한 비교용

    // 🚨 2026-08-12: 모든 모니터에 같은 내용을 표시하므로 단일 필드가 아니라 배열로 관리
    var titleFields: [NSTextField] = []
    var countdownFields: [NSTextField] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // 🔒 2026-09-22: 다른 어떤 것보다 먼저 검사한다. 특히 권한 요청창보다 앞이어야 한다 —
        // 임시 사본에서 돌고 있는데 권한창부터 띄우면, 사용자가 시스템 설정까지 들어가 켠 권한이
        // 다음 실행에 그대로 버려진다. 한 번 헛수고를 시키면 두 번째는 안 한다.
        if isRunningFromTemporaryCopy() {
            showTemporaryCopyGuideAndQuit()
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        askToStart()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEventTap()
    }

    func askToStart() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = Strings.confirmTitle
        alert.informativeText = Strings.confirmBody
        alert.addButton(withTitle: Strings.confirmStart)
        alert.addButton(withTitle: Strings.confirmCancel)

        // 🚨 2026-09-22: 만든 곳을 남기는 유일한 자리다.
        // 청소 화면(오버레이)에는 일부러 넣지 않는다 — 거기는 "지금 막혀 있고 이렇게 나간다"만
        // 말해야 하는 화면이라, 다른 정보가 탈출 안내와 시선을 나눠 갖게 하면 안 된다.
        // 이 확인창은 아직 키보드가 막히기 전이라 사람이 여유롭게 읽을 수 있다.
        // 주소는 고유명사라 번역이 필요 없어서 L() 을 쓰지 않는다.
        let credit = NSTextField(labelWithString: "github.com/Hyunjin-Cho")
        // 2026-09-22: 처음엔 11pt·tertiary 였는데 실물에서 너무 흐려 있는지도 모르고 지나갔다.
        // 12pt 로 키우고 색은 오너가 실물을 보고 본문과 같은 labelColor 로 확정했다
        // (중간 단계인 secondary 도 후보였으나 여전히 약하다는 판단).
        credit.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        credit.textColor = .labelColor
        credit.alignment = .center
        credit.isSelectable = true // 주소를 복사할 수 있게 (클릭으로 열리지는 않는다)
        credit.frame = NSRect(x: 0, y: 0, width: 320, height: 18)
        alert.accessoryView = credit

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            checkPermissionsAndStart()
        } else {
            NSApp.terminate(nil)
        }
    }

    // 🔒 2026-09-22: 안내만 하고 종료한다. 여기서 앱이 스스로 자신을 옮기는 선택지도 있었지만
    // (사본이 원본을 옮기는 꼴이라) 원본 위치를 되찾는 SPI 가 또 필요하고, 사용자가 어디에
    // 두고 싶은지도 알 수 없다. 옮기는 동작 자체가 translocation 을 푸는 유일한 사용자 동작이라
    // 사람이 직접 하는 편이 확실하다.
    func showTemporaryCopyGuideAndQuit() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = Strings.translocatedTitle
        alert.informativeText = Strings.translocatedBody
        alert.addButton(withTitle: Strings.ok)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.terminate(nil)
    }

    func checkPermissionsAndStart() {
        // (1) 손쉬운 사용 — 컴퓨터를 제어할 수 있는 권한
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let axTrusted = AXIsProcessTrustedWithOptions(options)

        // (2) 🚨 2026-08-12: 입력 모니터링 — 키 입력을 "가로챌" 수 있는 별도 권한.
        // macOS 10.15부터 키로거 방지를 위해 손쉬운 사용과 분리됐다. 손쉬운 사용만 켜져 있으면
        // CGEvent.tapCreate가 조용히 실패한다.
        // 더 중요한 건, 앱이 IOHIDRequestAccess로 직접 요청하지 않으면 시스템 설정의
        // '입력 모니터링' 목록에 나타나지도 않는다는 점 — 사용자가 켜고 싶어도 켤 항목이 없다.
        let hidGranted = requestInputMonitoringIfNeeded()

        if axTrusted && hidGranted {
            startCleaning()
            return
        }

        showPermissionGuide(axTrusted: axTrusted, hidGranted: hidGranted)
    }

    func requestInputMonitoringIfNeeded() -> Bool {
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted {
            return true
        }
        // 이 호출이 시스템 권한 요청창을 띄우고, 동시에 '입력 모니터링' 목록에 앱을 등록시킨다.
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        return false
    }

    func showPermissionGuide(axTrusted: Bool, hidGranted: Bool) {
        var missing: [String] = []
        if !axTrusted { missing.append(Strings.permissionAccessibility) }
        if !hidGranted { missing.append(Strings.permissionInputMonitoring) }

        // 입력 모니터링이 빠졌으면 그쪽을 먼저 안내한다(이게 없으면 키보드를 아예 못 막음)
        let openListenEvent = !hidGranted
        let anchor = openListenEvent ? "Privacy_ListenEvent" : "Privacy_Accessibility"
        let openButtonTitle = openListenEvent ? Strings.openInputMonitoring : Strings.openAccessibility

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = Strings.permissionTitle
        alert.informativeText = Strings.permissionBody(missing.joined(separator: "\n"))
        alert.addButton(withTitle: openButtonTitle)
        alert.addButton(withTitle: Strings.close)
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }

    func startCleaning() {
        // 화면에 종료 방법을 보여줄 수 없으면 키보드 차단 자체를 시작하지 않는다.
        // 보이지 않는 차단 상태가 되는 것보다 즉시 종료하는 편이 안전하다.
        guard createOverlayWindows() else {
            NSApp.terminate(nil)
            return
        }

        if !startEventTap() {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = Strings.tapFailedTitle
            alert.informativeText = Strings.tapFailedBody
            alert.addButton(withTitle: Strings.ok)
            closeOverlayWindows()
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        isCleaning = true
        remainingSeconds = totalSeconds
        startTimers()
        startSafetyTimer()
    }

    // MARK: - Overlay

    func createOverlayWindows() -> Bool {
        closeOverlayWindows()

        // 🚨 2026-08-12 수정: NSScreen.screens는 호출할 때마다 다른 인스턴스를 돌려줄 수 있어서
        // `screen == NSScreen.screens.first` 같은 비교가 항상 false가 될 수 있다(= 글자·버튼이
        // 어느 화면에도 안 그려짐). 한 번만 받아서 그 배열만 쓴다.
        // 동시에, 마우스가 어느 모니터에 있든 탈출 버튼을 누를 수 있도록 모든 화면에 콘텐츠를 그린다.
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return false }

        lastCountdownText = ""

        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            let window = OverlayWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            // 2026-08-12 최적화: display: true면 창을 띄우기도 전에 한 번 그리고 띄우면서 또 그린다.
            // 어차피 아래 orderFront에서 그려지므로 여기서는 좌표만 확정한다.
            window.setFrame(frame, display: false)
            window.level = .screenSaver
            window.isOpaque = true
            window.hasShadow = false
            window.backgroundColor = skyBlueColor
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.isReleasedWhenClosed = false

            // 2026-08-12 최적화: 하늘색은 창 배경색(window.backgroundColor)이 이미 칠한다.
            // 여기서 레이어 배경색까지 지정하면 전체화면 크기를 한 번 더 채우는 중복 작업이 된다.
            let contentView = NSView(frame: NSRect(origin: .zero, size: frame.size))
            contentView.wantsLayer = true
            window.contentView = contentView

            setupOverlayContent(in: contentView, size: frame.size)

            if index == 0 {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
            overlayWindows.append(window)
        }

        updateCountdownLabels()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func setupOverlayContent(in view: NSView, size: NSSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2

        // 🚨 2026-09-22: 화면이 작으면 배치 전체를 비례 축소한다.
        // 고정 오프셋만 쓰던 이전 코드는 600x340pt 미만 화면에서 탈출 버튼이 화면 밖으로
        // 나갔다(좌표 계산을 복제해 실측). 모니터를 3~4대 쓰는 구성에서 작은 보조
        // 디스플레이가 섞여 들어오는 경우가 여기 해당한다.
        // 버튼은 마우스로 쓸 수 있는 유일한 탈출구라, 어느 화면에서든 반드시 보여야 한다.
        //
        // 세로 기준 194 = 버튼 아래끝(170) + 아래 여백(24). 가로 기준 600 = 라벨 폭.
        // 하한 0.45를 두는 이유: 더 줄이면 글자가 읽히지 않아 안내로서 의미가 없어진다.
        // (그런 화면에서도 ⌘⇧9 와 190/195초 자동 해제는 그대로 남는다)
        let fit = min(1.0, (size.width - 40) / 600, (centerY - 24) / 194)
        let s = max(0.45, fit)

        // 폰트도 같은 비율로 줄인다. 배치만 줄이고 글자를 그대로 두면 서로 겹친다.
        let scaledTitleFont = s < 1 ? NSFont.systemFont(ofSize: 48 * s, weight: .semibold) : titleFont
        let scaledSubFont = s < 1 ? NSFont.systemFont(ofSize: 16 * s, weight: .regular) : subLabelFont
        let scaledCountFont = s < 1
            ? NSFont.monospacedDigitSystemFont(ofSize: 22 * s, weight: .regular) : countdownFont

        let label = NSTextField(labelWithString: cleaningTitles[0])
        label.font = scaledTitleFont
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: centerX - 300 * s, y: centerY + 10 * s, width: 600 * s, height: 70 * s)
        view.addSubview(label)
        titleFields.append(label)

        let subLabel = NSTextField(labelWithString: Strings.mouseHint)
        subLabel.font = scaledSubFont
        subLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        subLabel.alignment = .center
        subLabel.frame = NSRect(x: centerX - 300 * s, y: centerY - 30 * s, width: 600 * s, height: 24 * s)
        view.addSubview(subLabel)

        let countdown = NSTextField(labelWithString: formattedTime(remainingSeconds))
        countdown.font = scaledCountFont
        countdown.textColor = NSColor.white.withAlphaComponent(0.85)
        countdown.alignment = .center
        countdown.frame = NSRect(x: centerX - 150 * s, y: centerY - 80 * s, width: 300 * s, height: 30 * s)
        view.addSubview(countdown)
        countdownFields.append(countdown)

        // 🚨 2026-08-12: 탈출 단축키를 화면에 계속 띄워 둔다 — 마우스를 못 쓰는 상황의 마지막 안내
        let shortcutLabel = NSTextField(labelWithString: Strings.shortcutHint)
        shortcutLabel.font = scaledSubFont
        shortcutLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        shortcutLabel.alignment = .center
        shortcutLabel.frame = NSRect(x: centerX - 300 * s, y: centerY - 118 * s, width: 600 * s, height: 24 * s)
        view.addSubview(shortcutLabel)

        let button = OverlayButton(title: Strings.done, target: self, action: #selector(finishButtonTapped))
        button.frame = NSRect(x: centerX - 90 * s, y: centerY - 170 * s, width: 180 * s, height: 44 * s)
        // 🚨 2026-08-12: 시스템 기본 버튼 배경이 하늘색 배경 위에서 옅게 렌더링돼 안 보이는 문제
        // 방지 — 흰 배경 + 진한 텍스트로 명시적으로 대비를 줌
        button.isBordered = false
        button.attributedTitle = s < 1 ? NSAttributedString(
            string: Strings.done,
            attributes: [
                .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.5, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 18 * s, weight: .medium)
            ]) : buttonAttributedTitle
        button.applyRestingStyle(scale: s) // frame 확정 후에 호출 (그림자 경로가 bounds 기준)
        view.addSubview(button)
    }

    func closeOverlayWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
        titleFields.removeAll()
        countdownFields.removeAll()
    }

    // 🚨 2026-08-12: 청소 도중 모니터를 꽂거나 빼면 새 화면이 안 덮인 채로 남는다 → 오버레이 재구성
    @objc func screenParametersChanged() {
        guard isCleaning, !isFinishing else { return }
        // 화면이 모두 사라지면 보이지 않는 상태로 키보드 차단을 유지하지 않고 즉시 안전 종료한다.
        guard createOverlayWindows() else {
            finishCleaning()
            return
        }
    }

    func formattedTime(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }

    func updateCountdownLabels() {
        let text = formattedTime(remainingSeconds)
        // 2026-08-12 최적화: 표시할 값이 그대로면 화면을 다시 그릴 이유가 없다
        if text == lastCountdownText { return }
        lastCountdownText = text
        for field in countdownFields {
            field.stringValue = text
        }
    }

    // MARK: - Timers

    func startTimers() {
        dotCount = 0

        // 🚨 2026-08-12: .common 모드로 등록 — 모달·드래그 등 다른 런루프 모드에서도 계속 돌게 함
        // 2026-08-12 최적화: tolerance를 주면 macOS가 여러 타이머의 깨우기를 묶어 처리해 전력을 아낀다.
        // 점 애니메이션·카운트다운 모두 몇십 ms 늦어도 눈에 띄지 않는다.
        // 🚨 2026-09-22 오너 요청: 점 하나가 늘어나는 간격을 0.6초 → 1초로. 한 바퀴는 6초다.
        let dots = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.dotCount = (self.dotCount + 1) % cleaningTitles.count
            let title = cleaningTitles[self.dotCount]
            for field in self.titleFields {
                field.stringValue = title
            }
        }
        dots.tolerance = 0.2
        RunLoop.main.add(dots, forMode: .common)
        dotTimer = dots

        let countdown = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingSeconds -= 1
            if self.remainingSeconds <= 0 {
                self.finishCleaning()
                return
            }
            self.updateCountdownLabels()
        }
        countdown.tolerance = 0.1
        RunLoop.main.add(countdown, forMode: .common)
        countdownTimer = countdown
    }

    func startSafetyTimer() {
        // 🚨 안전장치(2026-08-12): dotTimer/countdownTimer가 무슨 이유로든 안 돌아도
        // 이 타이머는 독립적으로 돌아서 safetyLimitSeconds 뒤엔 무조건 풀어준다.
        // 카운트다운(180초)보다 10초 길어서 정상 동작을 가로채지 않는다.
        // (안전장치라 tolerance를 일부러 주지 않는다 — 한 번만 도는 타이머여서 전력에도 영향이 없다)
        let timer = Timer(timeInterval: safetyLimitSeconds, repeats: false) { [weak self] _ in
            self?.finishCleaning()
        }
        RunLoop.main.add(timer, forMode: .common)
        safetyTimer = timer

        // 🚨 2026-08-12: 최후의 보루 — Timer는 메인 런루프에 얹혀 있어서 앱이 멈추면 같이 멈춘다.
        // 런루프와 무관한 백그라운드 큐에서 시간을 재다가, 정상 종료가 안 됐으면 프로세스를 강제 종료한다.
        // 프로세스가 사라지면 이벤트탭도 함께 사라지므로 키보드는 무조건 복구된다.
        let deadline = DispatchTime.now() + safetyLimitSeconds + hardKillGraceSeconds
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: deadline) {
            exit(0)
        }
    }

    @objc func finishButtonTapped() {
        finishCleaning()
    }

    func finishCleaning() {
        if isFinishing { return }
        isFinishing = true
        isCleaning = false

        dotTimer?.invalidate()
        countdownTimer?.invalidate()
        safetyTimer?.invalidate()
        dotTimer = nil
        countdownTimer = nil
        safetyTimer = nil
        stopEventTap()
        closeOverlayWindows()
        NSApp.terminate(nil)
    }

    // MARK: - Keyboard blocking

    func startEventTap() -> Bool {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << 14) // NX_SYSDEFINED: 밝기·볼륨 등 미디어 키

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                // 2026-08-12 최적화: 이 콜백은 키를 누를 때마다(키를 꾹 누르면 초당 수십 번) 실행된다.
                // 여기가 느리면 macOS가 탭을 강제로 끊어버려 키보드가 순간 뚫리므로,
                // 힙 할당을 만들지 않고 필요한 값만 그때그때 꺼내 쓴다.
                // 🚨 2026-09-22 단서 추가: 아래 default 분기만 예외로 NSEvent 를 만든다.
                // 거기는 미디어 키(NX_SYSDEFINED)에서만 지나가므로 빈도가 낮아 괜찮다 —
                // 반대로 말하면 그 분기를 더 무겁게 만들면 안 된다.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let refcon = refcon {
                        let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                        if let tap = delegate.eventTap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }

                switch type {
                case .keyDown, .keyUp:
                    // 🚨 탈출 단축키(2026-08-12): Cmd+Shift+9이면 앱이 스스로 종료한다.
                    // 대부분의 키는 keycode 비교에서 바로 걸러지므로 flags는 '9'일 때만 읽는다.
                    if event.getIntegerValueField(.keyboardEventKeycode) == kVKANSI9 {
                        let flags = event.flags
                        if flags.contains(.maskCommand) && flags.contains(.maskShift) {
                            if type == .keyDown, let refcon = refcon {
                                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                                // 이 콜백 안에서 창을 닫고 종료하면 처리 시간이 길어져 macOS가 탭을
                                // 끊을 수 있다 → 다음 런루프 사이클로 미룬다.
                                DispatchQueue.main.async { delegate.finishCleaning() }
                            }
                            return nil // 다른 앱으로는 전달하지 않는다
                        }
                    }
                    return nil

                case .flagsChanged:
                    // 🚨 2026-08-12: Caps Lock만 차단하고 나머지 조합키(Cmd·Shift·Option·Control)는
                    // 통과시킨다. 시스템이 modifier 상태를 정확히 알아야 위 탈출 단축키 판정이 확실해지고,
                    // 조합키만으로는 아무 입력도 생기지 않는다(다른 키의 keyDown이 전부 막혀 있으므로).
                    // Caps Lock은 통과시키면 잠금이 토글돼 청소 후 대문자로 입력되는 부작용이 있어 막는다.
                    if event.getIntegerValueField(.keyboardEventKeycode) == kVKCapsLock {
                        return nil
                    }
                    return Unmanaged.passUnretained(event)

                default:
                    // 🚨 2026-08-12: NX_SYSDEFINED(14)에는 밝기·볼륨 같은 미디어 키 말고 다른 시스템
                    // 신호도 함께 실려 온다. 예전엔 이 통로를 통째로 삼켜서 엉뚱한 신호까지 막을 수
                    // 있었으므로, 미디어 키(subtype 8)만 골라 차단하고 나머지는 그대로 통과시킨다.
                    if type.rawValue == nxSysDefinedEventType,
                       let nsEvent = NSEvent(cgEvent: event),
                       nsEvent.type == .systemDefined,
                       nsEvent.subtype.rawValue == nxSubtypeAuxControlButtons {
                        return nil
                    }
                    return Unmanaged.passUnretained(event)
                }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
