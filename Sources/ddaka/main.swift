import Cocoa
import ApplicationServices
import IOKit.hid
import os

// 🚨 2026-09-23 (#10): 청소가 "어떻게" 끝났는지 macOS 로그에 남긴다. 끝나는 경로가 여섯 개
// (버튼 · 180초 카운트다운 · ⌘⇧9 · 190초 안전 타이머 · 195초 강제 종료 · 화면 소실)인데 기록이
// 한 줄도 없어서, "늦게 풀렸다" 같은 제보를 받아도 어느 층이 동작했는지 알 수 없었다.
// 🔒 키 입력 내용은 어떤 경우에도 기록하지 않는다 — 이 앱은 키보드 전체를 가로챈다.
// 🔒 이벤트탭 콜백 안에서는 로그를 찍지 않는다 — 키마다 도는 경로라 느려지면 macOS 가 탭을 끊는다.
//    콜백에서 생긴 일(탭이 꺼졌다 다시 켜짐)은 숫자만 세 두었다가 종료 때 한 줄로 남긴다.
// 확인: /usr/bin/log show --last 1h --predicate 'subsystem == "com.vismotive.ddaka"'
//      (README 「문제가 생겼을 때」와 짝이다 — 아래 FinishReason 값을 바꾸면 README 도 고친다)
//      전체 경로를 쓰는 이유: 비대화형 zsh 에서는 `log` 가 셸 내장 명령으로 잡혀 "too many arguments"
//      로 실패한다(2026-09-23 실측 — 터미널의 대화형 zsh 는 /etc/zshrc 의 `disable log` 덕에 괜찮다).
let appLog = Logger(subsystem: "com.vismotive.ddaka", category: "session")
// 195초 강제 종료는 정상 종료(0)와 구별되게 0 이 아닌 코드로 끝낸다.
let hardKillExitCode: Int32 = 3

enum FinishReason: String {
    case doneButton = "done-button"
    case countdown = "countdown"
    case shortcut = "shortcut"
    case safetyTimer = "safety-timer"
    case screensGone = "screens-gone"
}

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
    #if DEBUG
    // 2026-11-17 (#16): 미리보기(아래 --preview)에서 언어별 배치를 보려고. 배포 빌드에는 없다.
    if let forced = ProcessInfo.processInfo.environment["DDAKA_LANG"]?.lowercased() {
        switch forced {
        case "ko": return .ko
        case "ja": return .ja
        case "zh-hans": return .zhHans
        case "zh-hant": return .zhHant
        default: return .en
        }
    }
    #endif
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
    // 🚨 2026-11-17 (#16) 오너 결정 B안: 하늘색 단색 → 매번 다른 그림. "하늘색"이라는 약속을 5개 언어 모두에서 뺐다.
    static let confirmBody = L(
        "Your screen will be covered with a different picture each time, and every keystroke will be blocked for \(totalMinutes) minutes — or until you click “Done”. Your mouse and trackpad keep working.\n\nYou can quit at any time with ⌘⇧9.",
        "실행하면 화면이 매번 다른 그림으로 덮이고, 키보드 입력이 \(totalMinutes)분간(또는 '다 닦았어요' 버튼을 누를 때까지) 완전히 차단돼요. 마우스·트랙패드는 그대로 움직여요.\n\n언제든 ⌘⇧9 을 누르면 바로 종료돼요.",
        "画面が毎回ちがうイラストで覆われ、キーボード入力が\(totalMinutes)分間（または「完了」ボタンを押すまで）完全にブロックされます。マウス・トラックパッドはそのまま使えます。\n\n⌘⇧9 でいつでも終了できます。",
        "屏幕每次都会被一幅不同的插画覆盖，键盘输入将被完全阻止 \(totalMinutes) 分钟（或直到您点击“完成”按钮）。鼠标和触控板仍可正常使用。\n\n随时按 ⌘⇧9 即可退出。",
        "螢幕每次都會被一幅不同的插畫覆蓋，鍵盤輸入將被完全阻擋 \(totalMinutes) 分鐘（或直到您點擊「完成」按鈕）。滑鼠和觸控板仍可正常使用。\n\n隨時按 ⌘⇧9 即可結束。"
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
    // 나온다 — 안내가 시킨 동작이 그대로 함정이 된다.
    // 🚨 2026-09-23 정정: 이 자리에는 "그 반복 자체는 아직 재현하지 못했다(리뷰 F-5 는
    //    needs_check)"고 적혀 있었다. 2026-09-22 실기(macOS 27.0)에서 함정은 실재로 확인됐고,
    //    증상은 "같은 안내가 다시 뜬다"가 아니라 **"아무 반응이 없다"**였다 — 안내창이 이미 떠
    //    있으니 임시 사본이 앞으로 나와도 화면이 바뀌지 않는다. 문구는 함정을 줄일 뿐 없애지는
    //    못한다(README 「설치」 절의 실측 주석 ③과 같은 내용).
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
    // 🚨 2026-09-23 (#8): 한국어 문구는 전부 해요체로 맞춘다. 이 문구에는 "켜줘"(반말)가 있어서
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

// 🚨 2026-11-17 (#16) 오너 결정: 제목 뒤 점(…) 애니메이션을 없앴다. 화면이 멈추지 않았다는 신호는
// 1초마다 줄어드는 카운트다운이 맡는다(점은 원래 "멈춘 것 같다"는 느낌을 없애려고 넣었던 것이다).

// 2026-08-12 최적화: 색·폰트·문구는 모니터 수만큼 다시 만들 이유가 없어 한 번만 만들어 공유한다
//
// 🚨 2026-09-23 (#9): 색은 전부 sRGB 로 적는다. 종전에는 NSColor(calibratedRed:)였는데, 이건
// sRGB 가 아니라 **Generic RGB** 공간의 숫자다. 하늘색 0.53/0.81/0.92 는 #87CEEB 를 소수로 옮긴
// 값이었지만 화면에는 sRGB #97D7EF 로 나갔다(더 밝고 옅음, ΔE2000 3.00 — 시스템 색 변환으로 측정).
// - 하늘색은 의도했던 #87CEEB 로 정확히 맞춘다. 앱 아이콘도 이 값을 기준으로 만들었다.
// - 나머지 색은 **지금 화면에 보이던 색을 그대로** sRGB 8bit 로 옮겼다(바꾸기 전과 ΔE2000 0.06 이하).
// 🔒 hex·브랜드 색은 sRGB 값이다 — 새 색을 넣을 때도 공간이 이름에 드러나는 srgbRed: 를 쓴다.
// 2026-11-17 (#16): 그림 테마가 들어오면서 하늘색은 "그림을 못 읽었을 때" 물러날 바탕으로만 남는다.
let skyBlueColor = NSColor(srgbRed: 135.0 / 255, green: 206.0 / 255, blue: 235.0 / 255, alpha: 1.0) // #87CEEB
// 🚨 2026-11-17 (#16) 오너: "버튼이 빨간색이라 이상하다 — 파스텔로". 파스텔 산호 + 짙은 자두색 글자(7.5:1).
// 모든 테마에서 같은 색이다 — 랜덤으로 그림이 바뀌어도 "그 버튼"을 찾으면 된다(지각 교수 2026-11-17).
// 눌림은 여전히 "아래 두께(그림자)가 줄며 가라앉는 것"으로 표현한다(2026-08-12 원칙).
let buttonFillColor = NSColor(srgbRed: 0xF4 / 255.0, green: 0xB6 / 255.0, blue: 0xA4 / 255.0, alpha: 1).cgColor   // #F4B6A4
let buttonPressedFillColor = NSColor(srgbRed: 0xEF / 255.0, green: 0xA8 / 255.0, blue: 0x95 / 255.0, alpha: 1).cgColor // #EFA895
let buttonEdgeColor = NSColor(srgbRed: 0xD9 / 255.0, green: 0x8C / 255.0, blue: 0x78 / 255.0, alpha: 1).cgColor   // #D98C78
let buttonTextColor = NSColor(srgbRed: 0x3A / 255.0, green: 0x2B / 255.0, blue: 0x45 / 255.0, alpha: 1)           // #3A2B45
// 알약 속 숫자 — 알약이 늘 크림색이라 장면과 상관없이 짙은 색 하나.
let countdownInkColor = NSColor(srgbRed: 0x2B / 255.0, green: 0x25 / 255.0, blue: 0x52 / 255.0, alpha: 1)         // #2B2552

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

    // 2026-11-17 (#16): 글자를 버튼 높이의 가운데에 그린다. 테두리 없는 버튼의 기본 셀은 글자를 위로 붙였다
    // (미리보기 실측). 눌림·첫 클릭 동작은 셀이 아니라 이 클래스가 맡으므로 그대로다.
    override class var cellClass: AnyClass? {
        get { CenteredTitleButtonCell.self }
        set {}
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // 2026-08-12: 평상시 모양. frame을 정한 뒤에 불러야 한다(shadowPath가 bounds를 쓰므로).
    // 흰 배경만 깔면 "평평한 사각형"이라 눌러도 눌린 느낌이 안 난다 → 그림자로 살짝 띄운다.
    // 2026-09-22: scale 은 작은 화면에서 배치가 줄어든 비율. 모서리와 그림자만 원래 크기로
    // 남으면 버튼이 뭉툭해 보여서 함께 줄인다.
    func applyRestingStyle(scale: CGFloat = 1.0) {
        wantsLayer = true
        guard let layer = layer else { return }
        cornerScale = scale
        // 2026-11-17 (#16): 알약 모양 + 아래로 4pt 비치는 두께(번짐 없는 그림자)
        layer.backgroundColor = buttonFillColor
        layer.cornerRadius = bounds.height / 2
        layer.borderWidth = 0
        layer.masksToBounds = false // 그림자가 잘리지 않게
        layer.shadowColor = buttonEdgeColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: -4 * scale) // macOS는 y가 위쪽이 + → 음수가 아래
        // 경로를 직접 주면 매 프레임 알파를 훑어 그림자를 계산하지 않는다(그리기 비용 절감)
        layer.shadowPath = CGPath(roundedRect: bounds, cornerWidth: bounds.height / 2,
                                  cornerHeight: bounds.height / 2, transform: nil)
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
        layer?.backgroundColor = pressed ? buttonPressedFillColor : buttonFillColor
        layer?.shadowOffset = CGSize(width: 0, height: (pressed ? -1 : -4) * cornerScale)
        CATransaction.commit()
    }
}

final class CenteredTitleButtonCell: NSButtonCell {
    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        let size = title.size()
        let rect = NSRect(x: frame.minX + (frame.width - size.width) / 2,
                          y: controlView.bounds.minY + (controlView.bounds.height - size.height) / 2,
                          width: size.width, height: size.height)
        title.draw(in: rect)
        return rect
    }
}

// 2026-11-18 (#20): 실행 확인창의 주소 줄. 누르면 기본 브라우저로 저장소 페이지를 연다.
// 종전에는 복사만 되는 글자였다(실물 확인 — 손쉬운 사용 역할이 AXStaticText 였다).
// - 키보드 초점은 받지 않는다: 확인창의 Return = "예" · Esc 동작을 그대로 두려는 것.
// - 확인창이 떠 있는 동안 브라우저가 열려도 확인창은 닫히지 않고, 키보드는 아직 막히기 전이다.
final class LinkButton: NSButton {
    private let url: URL

    init(title: String, url: URL, font: NSFont) {
        self.url = url
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        refusesFirstResponder = true
        attributedTitle = Self.linkTitle(title, font: font, color: .linkColor)
        // 누르고 있는 동안만 조금 옅게 — momentaryChange 는 이 제목으로 바꿔 그린다
        attributedAlternateTitle = Self.linkTitle(title, font: font,
                                                  color: NSColor.linkColor.withAlphaComponent(0.55))
        toolTip = url.absoluteString // 주소라 번역이 필요 없다
        setAccessibilityRole(.link)
        target = self
        action = #selector(openLink)
        sizeToFit()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private static func linkTitle(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    @objc private func openLink() {
        appLog.notice("start dialog: opened \(self.url.absoluteString, privacy: .public)")
        NSWorkspace.shared.open(url)
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
    var countdownTimer: Timer?
    var safetyTimer: Timer?
    var remainingSeconds = totalSeconds
    var isCleaning = false
    var isFinishing = false
    var lastCountdownText = "" // 2026-08-12 최적화: 값이 안 바뀌었으면 화면을 다시 그리지 않기 위한 비교용
    // 2026-09-23 (#10): 종료 로그용. 시작 시각은 단조 시계로 잰다(벽시계는 사용자가 바꿀 수 있다).
    var cleaningStartedAt: DispatchTime?
    // 이벤트탭이 macOS 에 의해 꺼졌다가 다시 켜진 횟수 — 콜백 안에서는 세기만 한다(위 🔒 참조).
    var tapReenableCount = 0

    // 🚨 2026-08-12: 모든 모니터에 같은 내용을 표시하므로 단일 필드가 아니라 배열로 관리
    var countdownViews: [CountdownView] = []
    // 2026-11-17 (#16): 이번 실행의 테마. 청소를 시작할 때 한 번 고르고, 모니터가 바뀌어 화면을 다시 그려도 그대로 쓴다.
    var theme: Theme = allThemes[0]
    var themeArt: ThemeArt?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // 🔒 2026-09-22: 다른 어떤 것보다 먼저 검사한다. 특히 권한 요청창보다 앞이어야 한다 —
        // 임시 사본에서 돌고 있는데 권한창부터 띄우면, 사용자가 시스템 설정까지 들어가 켠 권한이
        // 다음 실행에 그대로 버려진다. 한 번 헛수고를 시키면 두 번째는 안 한다.
        if isRunningFromTemporaryCopy() {
            appLog.notice("quit: running from a translocated temporary copy")
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
        // 2026-09-22: 처음엔 11pt·tertiary 였는데 실물에서 너무 흐려 있는지도 모르고 지나갔다.
        // 12pt 로 키우고 색은 오너가 실물을 보고 본문과 같은 labelColor 로 확정했다
        // (중간 단계인 secondary 도 후보였으나 여전히 약하다는 판단).
        // 2026-11-18 (#20): 오너 — 앱 안의 홍보가 약하다. 복사만 되던 글자를 누르면 열리는 링크로 바꾸고,
        // 가리키는 곳을 프로필에서 저장소(받기·업데이트·설명이 있는 곳)로 옮겼다. 색은 링크라는 표시로
        // labelColor 대신 시스템 링크색 + 밑줄(다크 모드에서도 시스템이 맞춘다). 크기 12pt 는 그대로.
        let credit = LinkButton(title: "github.com/Hyunjin-Cho/ddak-a",
                                url: URL(string: "https://github.com/Hyunjin-Cho/ddak-a")!,
                                font: NSFont.systemFont(ofSize: 12, weight: .regular))
        // 확인창 폭에 맞춘 칸 가운데에 글자 크기만큼만 둔다 — 손가락 커서가 빈 곳에서 뜨지 않게.
        let creditRow = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 18))
        credit.frame.origin = NSPoint(x: ((creditRow.bounds.width - credit.frame.width) / 2).rounded(),
                                      y: ((creditRow.bounds.height - credit.frame.height) / 2).rounded())
        creditRow.addSubview(credit)
        alert.accessoryView = creditRow

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            checkPermissionsAndStart()
        } else {
            appLog.notice("quit: user declined to start")
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
        appLog.notice("quit: missing permissions accessibility=\(axTrusted, privacy: .public) inputMonitoring=\(hidGranted, privacy: .public)")
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
        // 2026-11-17 (#16): 그림을 먼저 읽는다. 못 읽어도 멈추지 않는다 — 하늘색 바탕에 같은 글자·버튼을 그린다.
        theme = pickTheme()
        themeArt = ThemeArt.load(theme)

        // 화면에 종료 방법을 보여줄 수 없으면 키보드 차단 자체를 시작하지 않는다.
        // 보이지 않는 차단 상태가 되는 것보다 즉시 종료하는 편이 안전하다.
        guard createOverlayWindows() else {
            appLog.error("quit: could not create overlay windows (no screens)")
            NSApp.terminate(nil)
            return
        }

        if !startEventTap() {
            appLog.error("quit: CGEvent.tapCreate failed")
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
        cleaningStartedAt = .now()
        appLog.notice("cleaning started: screens=\(self.overlayWindows.count, privacy: .public) theme=\(self.theme.id, privacy: .public) art=\(self.themeArt != nil, privacy: .public) limit=\(totalSeconds, privacy: .public)s")
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
            window.backgroundColor = themeArt?.topColor ?? skyBlueColor
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.isReleasedWhenClosed = false

            // 2026-08-12 최적화: 바탕색은 창 배경색(window.backgroundColor)이 이미 칠한다.
            // 여기서 레이어 배경색까지 지정하면 전체화면 크기를 한 번 더 채우는 중복 작업이 된다.
            // (2026-11-17 #16: 그림 테마에서는 그림 맨 위 줄의 색 — 세로 모니터에서 그림 위로 이어지는 하늘이다)
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

    // 🚨 2026-11-17 (#16): 배치의 본체를 그림 테마에 맞춰 다시 짰다. 원칙은 그대로다.
    // - 청소 화면은 "지금 막혀 있고, 이렇게 나간다"만 말한다 → 글자는 두 묶음뿐:
    //   상황(제목·마우스 안내)은 그림 속 하늘의 빈 자리에, 나가는 법(시간·버튼·⌘⇧9)은 반투명 알약 하나에.
    //   (지각심리 교수 2026-11-17: 위치는 테마마다 달라도 "그 알약"을 찾으면 된다. 시간은 버튼 바로 옆 —
    //    1초마다 바뀌는 숫자가 눈을 출구로 데려온다.)
    // - 탈출 버튼은 어느 화면에서든 보여야 하고 맨 위에 있어야 한다 → 모든 묶음을 화면 안쪽 여백으로 끌어당기고,
    //   버튼을 가장 마지막에 얹는다.
    // - 작은 화면(보조 모니터)에서는 비례 축소하되 하한을 둔다(2026-09-22 원칙 — 글자가 안 읽히면 안내로서 의미가 없다).
    // 시안: ~/Documents/myProjects/ddaka-themes/r2/scene.html · ui.js (같은 계산을 그대로 옮겼다)
    func setupOverlayContent(in view: NSView, size: NSSize) {
        let W = size.width
        let H = size.height
        let margin: CGFloat = 24        // 둥근 화면 모서리
        let notchMargin: CGFloat = 48   // 위쪽 — 노치가 있는 맥북에서 제목이 가려지지 않게
        let s = min(1.3, max(0.62, min(W / 1440, H / 900)))
        let clamp = { (v: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat in max(lo, min(hi, v)) }

        // 그림을 못 읽었으면 하늘색 바탕 + 가운데 배치로 물러난다(글자·버튼은 똑같이 그린다).
        let t = themeArt == nil ? plainTheme : theme

        // ── 1) 그림: 16:10 보다 넓은 화면은 꽉 채우고(아래 기준 — 위쪽 하늘이 잘린다),
        //    그보다 좁은 화면(4:3·세로 모니터)은 폭에 맞춰 아래에 두고 위는 그림 맨 위 색으로 잇는다.
        //    (2026-11-17: 세로 모니터에서 양옆을 자르면 주인공이 잘렸다 — 시안 실측)
        var art = NSRect(x: 0, y: 0, width: W, height: H)
        var narrow = false
        if let themeArt = themeArt {
            let aspect = themeArt.image.size.width / max(1, themeArt.image.size.height)
            if W / H >= 1.5 {
                let h = max(H, W / aspect)
                art = NSRect(x: (W - h * aspect) / 2, y: 0, width: h * aspect, height: h)
            } else {
                narrow = true
                art = NSRect(x: 0, y: 0, width: W, height: W / aspect)
            }
            let imageView = NSImageView(frame: art)
            imageView.image = themeArt.image
            imageView.imageScaling = .scaleAxesIndependently
            imageView.imageFrameStyle = .none
            view.addSubview(imageView)
            if narrow {
                // 그림 윗변과 이어 칠한 하늘 사이의 경계를 부드럽게 번지게 한다(경계선이 보이면 "붙인 그림"이 된다).
                let fade = SkyFadeView(frame: NSRect(x: 0, y: art.maxY - art.height * 0.14, width: W, height: art.height * 0.14 + 1))
                fade.color = themeArt.topColor
                view.addSubview(fade)
            }
        }
        // 그림 좌표(u, v)를 화면 좌표로. AppKit 은 아래가 0 이라 v 를 뒤집는다.
        let point = { (p: CGPoint) -> CGPoint in
            CGPoint(x: art.minX + p.x * art.width, y: art.minY + (1 - p.y) * art.height)
        }
        let k = art.height / 1200   // 시안의 viewBox 1단위가 화면에서 몇 pt 인지

        let textShadow: NSShadow? = {
            guard t.lightText else { return nil }
            let sh = NSShadow()
            sh.shadowColor = NSColor(srgbRed: 20 / 255, green: 28 / 255, blue: 60 / 255, alpha: 0.55)
            sh.shadowBlurRadius = 10
            sh.shadowOffset = NSSize(width: 0, height: -1)
            return sh
        }()

        // ── 2) 상황 묶음: 제목(한 줄 — 폭에 맞춰 줄인다) + 마우스 안내(최대 두 줄)
        let capW = min(W - 2 * margin, max(340 * s, 760 * k))
        var titleSize = clamp(max(66 * k, narrow ? 56 * s : 0), 32, 84) * 0.8
        func titleString(_ size: CGFloat) -> NSAttributedString {
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center   // 글자 꾸밈(NSAttributedString)을 쓰면 필드의 alignment 는 무시된다
            var a: [NSAttributedString.Key: Any] = [.font: overlayFont(size: size), .foregroundColor: t.ink,
                                                    .kern: size * 0.02, .paragraphStyle: centered]
            if let sh = textShadow { a[.shadow] = sh }
            return NSAttributedString(string: Strings.cleaning, attributes: a)
        }
        while titleString(titleSize).size().width > capW - 8, titleSize > 20 { titleSize -= 1 }
        let title = NSTextField(labelWithAttributedString: titleString(titleSize))
        title.alignment = .center
        title.maximumNumberOfLines = 1
        title.lineBreakMode = .byClipping
        let titleH = ceil(titleString(titleSize).size().height) + 4

        let hintSize = clamp(21 * k, 15, 24)
        var hintAttrs: [NSAttributedString.Key: Any] = [.font: overlayFont(size: hintSize), .foregroundColor: t.ink]
        if let sh = textShadow { hintAttrs[.shadow] = sh }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = hintSize * 0.25
        hintAttrs[.paragraphStyle] = paragraph
        let hintText = NSAttributedString(string: Strings.mouseHint, attributes: hintAttrs)
        let mouseHint = NSTextField(labelWithAttributedString: hintText)
        mouseHint.maximumNumberOfLines = 2
        mouseHint.lineBreakMode = .byWordWrapping
        mouseHint.preferredMaxLayoutWidth = capW
        let hintH = ceil(hintText.boundingRect(with: NSSize(width: capW, height: 200),
                                               options: [.usesLineFragmentOrigin]).height) + 4
        let gap = hintSize * 0.55
        let capH = titleH + gap + hintH

        var capCenter = point(t.caption)
        if narrow {
            // 세로 모니터: 가운데, 그림 위로 이어지는 하늘에
            let skyFromTop = H - art.maxY
            capCenter = CGPoint(x: W / 2, y: H - max(margin + notchMargin + capH / 2, skyFromTop * 0.42))
        }
        let capX = clamp(capCenter.x - capW / 2, margin, W - margin - capW)
        let capY = clamp(capCenter.y - capH / 2, margin, H - margin - notchMargin - capH)
        mouseHint.frame = NSRect(x: capX, y: capY, width: capW, height: hintH)
        title.frame = NSRect(x: capX, y: capY + hintH + gap, width: capW, height: titleH)
        view.addSubview(title)
        view.addSubview(mouseHint)

        // ── 3) 나가는 법 묶음: 반투명 알약(시간 + 버튼) + 그 아래 ⌘⇧9 안내
        let ss = s * 0.82
        let countdown = CountdownView(font: countdownFontNamed(size: 26 * ss), color: countdownInkColor)
        countdown.text = formattedTime(remainingSeconds)
        let cd = countdown.intrinsicContentSize

        let buttonTitle = NSAttributedString(string: Strings.done, attributes: [
            .foregroundColor: buttonTextColor,
            .font: overlayFont(size: 18 * ss)
        ])
        let bw = max(150 * ss, ceil(buttonTitle.size().width) + 44 * ss)
        let bh = max(42 * ss, ceil(buttonTitle.size().height) + 22 * ss)
        let padL = 18 * ss, padR = 6 * ss, padV = 6 * ss, rowGap = 10 * ss
        let pillW = padL + cd.width + rowGap + bw + padR
        let pillH = bh + 2 * padV

        let hintColor = t.ink
        let halo = NSShadow()
        halo.shadowBlurRadius = 6
        halo.shadowOffset = .zero
        halo.shadowColor = t.lightText
            ? NSColor(srgbRed: 20 / 255, green: 28 / 255, blue: 60 / 255, alpha: 0.85)
            : NSColor(srgbRed: 1, green: 252 / 255, blue: 245 / 255, alpha: 0.95)
        let shortcutSize = max(13, 14 * ss)
        let shortcutText = shortcutAttributed(Strings.shortcutHint, size: shortcutSize, color: hintColor, shadow: halo)
        let scW = ceil(shortcutText.size().width) + 12
        let scH = ceil(shortcutText.size().height) + 4
        let scGap = 8 * ss

        let groupW = max(pillW, scW)
        let groupH = pillH + scGap + scH
        let anchor = point(t.sign)
        let gx = clamp(anchor.x - groupW / 2, margin, W - margin - groupW)
        let gy = clamp(anchor.y, margin, H - margin - groupH)

        let pillX = gx + (groupW - pillW) / 2
        let pillY = gy + scH + scGap
        let pill = PillView(frame: NSRect(x: pillX - 6, y: pillY - 6, width: pillW + 12, height: pillH + 12))
        view.addSubview(pill)

        countdown.frame = NSRect(x: pillX + padL, y: pillY + (pillH - cd.height) / 2, width: cd.width, height: cd.height)
        view.addSubview(countdown)
        countdownViews.append(countdown)

        let shortcutLabel = NSTextField(labelWithAttributedString: shortcutText)
        shortcutLabel.alignment = .center
        shortcutLabel.frame = NSRect(x: gx + (groupW - scW) / 2, y: gy, width: scW, height: scH)
        view.addSubview(shortcutLabel)

        // 버튼은 맨 마지막에 얹는다 — 어떤 그림·글자도 버튼 위를 덮지 않는다(첫 클릭이 버튼으로 가야 한다).
        let button = OverlayButton(title: Strings.done, target: self, action: #selector(finishButtonTapped))
        button.frame = NSRect(x: pillX + padL + cd.width + rowGap, y: pillY + padV, width: bw, height: bh)
        button.isBordered = false
        button.attributedTitle = buttonTitle
        button.applyRestingStyle(scale: ss) // frame 확정 후에 호출 (그림자 경로가 bounds 기준)
        view.addSubview(button)
    }

    func closeOverlayWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
        countdownViews.removeAll()
    }

    // 🚨 2026-08-12: 청소 도중 모니터를 꽂거나 빼면 새 화면이 안 덮인 채로 남는다 → 오버레이 재구성
    @objc func screenParametersChanged() {
        guard isCleaning, !isFinishing else { return }
        // 화면이 모두 사라지면 보이지 않는 상태로 키보드 차단을 유지하지 않고 즉시 안전 종료한다.
        guard createOverlayWindows() else {
            finishCleaning(reason: .screensGone)
            return
        }
        appLog.notice("screens changed: overlays rebuilt on \(self.overlayWindows.count, privacy: .public) screen(s)")
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
        for view in countdownViews {
            view.text = text
        }
    }

    // MARK: - Timers

    func startTimers() {
        // 🚨 2026-08-12: .common 모드로 등록 — 모달·드래그 등 다른 런루프 모드에서도 계속 돌게 함
        // 2026-08-12 최적화: tolerance를 주면 macOS가 여러 타이머의 깨우기를 묶어 처리해 전력을 아낀다.
        // 카운트다운은 몇십 ms 늦어도 눈에 띄지 않는다.
        // 2026-11-17 (#16): 점 애니메이션 타이머를 없앴다(제목은 이제 바뀌지 않는다).
        let countdown = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingSeconds -= 1
            if self.remainingSeconds <= 0 {
                self.finishCleaning(reason: .countdown)
                return
            }
            self.updateCountdownLabels()
        }
        countdown.tolerance = 0.1
        RunLoop.main.add(countdown, forMode: .common)
        countdownTimer = countdown
    }

    func startSafetyTimer() {
        // 🚨 안전장치(2026-08-12): countdownTimer가 무슨 이유로든 안 돌아도
        // 이 타이머는 독립적으로 돌아서 safetyLimitSeconds 뒤엔 무조건 풀어준다.
        // 카운트다운(180초)보다 10초 길어서 정상 동작을 가로채지 않는다.
        // (안전장치라 tolerance를 일부러 주지 않는다 — 한 번만 도는 타이머여서 전력에도 영향이 없다)
        let timer = Timer(timeInterval: safetyLimitSeconds, repeats: false) { [weak self] _ in
            self?.finishCleaning(reason: .safetyTimer)
        }
        RunLoop.main.add(timer, forMode: .common)
        safetyTimer = timer

        // 🚨 2026-08-12: 최후의 보루 — Timer는 메인 런루프에 얹혀 있어서 앱이 멈추면 같이 멈춘다.
        // 런루프와 무관한 백그라운드 큐에서 시간을 재다가, 정상 종료가 안 됐으면 프로세스를 강제 종료한다.
        // 프로세스가 사라지면 이벤트탭도 함께 사라지므로 키보드는 무조건 복구된다.
        // 🚨 2026-09-23 (#10): 종료 코드를 0 -> hardKillExitCode 로. 정상 종료와 구별되게 하고,
        // 로그에 fault 로 남긴다(이게 찍혔다면 정상 경로가 전부 실패했다는 뜻이다).
        let deadline = DispatchTime.now() + safetyLimitSeconds + hardKillGraceSeconds
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: deadline) {
            appLog.fault("hard kill: the process was still alive \(safetyLimitSeconds + hardKillGraceSeconds, format: .fixed(precision: 0), privacy: .public)s after start")
            exit(hardKillExitCode)
        }
    }

    @objc func finishButtonTapped() {
        finishCleaning(reason: .doneButton)
    }

    func finishCleaning(reason: FinishReason) {
        if isFinishing { return }
        isFinishing = true
        isCleaning = false

        // 2026-09-23 (#10): 끝난 순간의 경과 시간은 여기서 재고, 기록은 키보드를 푼 **뒤에** 남긴다
        // (차단 해제가 늘 먼저다 — 로그가 그 앞을 가로막을 이유가 없다).
        let elapsed = cleaningStartedAt.map {
            Double(DispatchTime.now().uptimeNanoseconds - $0.uptimeNanoseconds) / 1_000_000_000
        } ?? -1

        countdownTimer?.invalidate()
        safetyTimer?.invalidate()
        countdownTimer = nil
        safetyTimer = nil
        stopEventTap()
        // 어느 장치가 끝냈는지 · 시작 뒤 몇 초였는지 · 탭이 몇 번 끊겼는지.
        appLog.notice("cleaning finished: reason=\(reason.rawValue, privacy: .public) elapsed=\(elapsed, format: .fixed(precision: 1), privacy: .public)s tapReenabled=\(self.tapReenableCount, privacy: .public)")
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
                        // 2026-09-23 (#10): 여기서는 세기만 한다(정수 증가 — 할당 없음). 로그는 종료 때.
                        delegate.tapReenableCount += 1
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
                                DispatchQueue.main.async { delegate.finishCleaning(reason: .shortcut) }
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

#if DEBUG
// 2026-11-17 (#16): 키보드를 막지 않고 청소 화면 배치만 PNG 로 뽑는다(디버그 빌드 전용 — 배포 빌드에는 이 길이 없다).
// 청소 화면은 키보드를 막는 앱이라 실행해서 볼 수가 없다. 테마·언어·화면 크기마다 배치가 맞는지는 이걸로 본다.
// 사용: DDAKA_ASSETS=assets DDAKA_LANG=ko .build/debug/ddaka --preview <폴더> [테마 id ...]
//      결과: <폴더>/<테마>-<언어>-<가로>x<세로>.png (화면 크기 4가지)
final class PreviewButtonBackdrop: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0, dy: 6)
        let edge = NSBezierPath(roundedRect: r.offsetBy(dx: 0, dy: -4 * r.height / 44), xRadius: r.height / 2, yRadius: r.height / 2)
        NSColor(cgColor: buttonEdgeColor)?.setFill(); edge.fill()
        let face = NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2)
        NSColor(cgColor: buttonFillColor)?.setFill(); face.fill()
    }
}

if let i = CommandLine.arguments.firstIndex(of: "--preview"), i + 1 < CommandLine.arguments.count {
    _ = NSApplication.shared
    let outDir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let wanted = Set(CommandLine.arguments.dropFirst(i + 2))
    let lang = ProcessInfo.processInfo.environment["DDAKA_LANG"] ?? "en"
    let sizes: [NSSize] = [NSSize(width: 1440, height: 900), NSSize(width: 1920, height: 1080),
                           NSSize(width: 800, height: 500), NSSize(width: 1080, height: 1920)]
    for theme in allThemes + [plainTheme] where wanted.isEmpty || wanted.contains(theme.id) {
        let previewer = AppDelegate()
        previewer.theme = theme
        previewer.themeArt = theme.id == "plain" ? nil : ThemeArt.load(theme)
        previewer.remainingSeconds = 177
        for size in sizes {
            let view = NSView(frame: NSRect(origin: .zero, size: size))
            view.wantsLayer = true
            view.layer?.backgroundColor = (previewer.themeArt?.topColor ?? skyBlueColor).cgColor
            previewer.setupOverlayContent(in: view, size: size)
            // 창 없이 그리면 레이어 속성(버튼의 배경·두께)은 그려지지 않는다 → 미리보기에서만 같은 값으로 밑그림을 깐다.
            for case let button as OverlayButton in view.subviews {
                let backdrop = PreviewButtonBackdrop(frame: button.frame.insetBy(dx: 0, dy: -6))
                view.addSubview(backdrop, positioned: .below, relativeTo: button)
            }
            // 배치 검사(미리보기 전용): 글자·알약·버튼이 화면 안쪽 여백 안에 있는지, 두 묶음이 겹치지 않는지.
            let items = view.subviews.filter { !($0 is NSImageView) && !($0 is PreviewButtonBackdrop) && !($0 is SkyFadeView) }
            let inner = NSRect(origin: .zero, size: size).insetBy(dx: 24 - 7, dy: 24 - 7)   // 알약 그림자 여유 6pt + 반올림
            for v in items where !inner.contains(v.frame) {
                print("⚠️ \(theme.id) \(lang) \(Int(size.width))x\(Int(size.height)): \(type(of: v)) 가 여백 밖 \(v.frame)")
            }
            let texts = items.compactMap { $0 as? NSTextField }
            if texts.count >= 2, let pill = items.first(where: { $0 is PillView }) {
                let caption = texts[0].frame.union(texts[1].frame)
                if caption.intersects(pill.frame.insetBy(dx: 6, dy: 6)) {
                    print("⚠️ \(theme.id) \(lang) \(Int(size.width))x\(Int(size.height)): 제목 묶음과 알약이 겹침")
                }
            }
            if let last = view.subviews.last, !(last is OverlayButton) {
                print("⚠️ \(theme.id) \(lang): 버튼이 맨 위가 아님")
            }
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let name = "\(theme.id)-\(lang)-\(Int(size.width))x\(Int(size.height)).png"
            try? rep.representation(using: .png, properties: [:])?.write(to: outDir.appendingPathComponent(name))
        }
    }
    exit(0)
}
#endif

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
