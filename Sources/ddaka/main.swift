import Cocoa
import ApplicationServices
import IOKit.hid

let totalSeconds = 300 // 5분
let testSafetyLimitSeconds: TimeInterval = 60 // 🚨 테스트 기간 안전장치 — 다른 로직이 다 실패해도 이 시간 지나면 무조건 풀림 (2026-08-12)
let hardKillGraceSeconds: TimeInterval = 5 // 세이프티 타이머가 정상 종료에 실패했을 때 프로세스를 강제로 죽이기까지의 여유 (2026-08-12)

// 2026-08-12 최적화: 0.6초마다 문자열을 새로 조립하지 않도록 4가지 상태를 미리 만들어 둔다
let cleaningTitles = [
    "키보드 청소중",
    "키보드 청소중.",
    "키보드 청소중..",
    "키보드 청소중..."
]

// 2026-08-12 최적화: 색·폰트·문구는 모니터 수만큼 다시 만들 이유가 없어 한 번만 만들어 공유한다
let skyBlueColor = NSColor(calibratedRed: 0.53, green: 0.81, blue: 0.92, alpha: 1.0)
let buttonNormalColor = NSColor.white.cgColor
let buttonPressedColor = NSColor(calibratedWhite: 0.80, alpha: 1.0).cgColor // 눌렸을 때 음영
let titleFont = NSFont.systemFont(ofSize: 48, weight: .semibold)
let subLabelFont = NSFont.systemFont(ofSize: 16, weight: .regular)
let countdownFont = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .regular)
let buttonAttributedTitle = NSAttributedString(
    string: "다 닦았어요",
    attributes: [
        .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.5, alpha: 1.0),
        .font: NSFont.systemFont(ofSize: 18, weight: .medium)
    ]
)

// 2026-08-12 최적화: 이벤트탭 콜백은 키 입력마다 실행되고, 느리면 macOS가 탭을 강제로 끊는다
// (= 키보드가 순간 뚫림). 콜백 안에서는 힙 할당이 생기지 않도록 상수만 쓰고 switch로 비교한다.
private let kVKEscape: Int64 = 53
private let kVKCommand: Int64 = 55
private let kVKRightCommand: Int64 = 54
private let kVKOption: Int64 = 58
private let kVKRightOption: Int64 = 61
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
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // 2026-08-12 추가: isBordered = false + 커스텀 배경이라 시스템 기본 눌림 효과가 없다.
    // super.mouseDown은 마우스를 뗄 때까지 안에서 트래킹하므로, 그 앞뒤를 감싸면
    // "누르고 있는 동안"만 정확히 어둡게 만들 수 있다.
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
        CATransaction.commit()
    }
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
        alert.messageText = "닦아 실행할까요?"
        alert.informativeText = "실행하면 화면이 하늘색으로 덮이고, 키보드 입력이 5분간(또는 '다 닦았어요' 버튼을 누를 때까지) 완전히 차단돼요. 마우스·트랙패드는 그대로 움직여요."
        alert.addButton(withTitle: "예")
        alert.addButton(withTitle: "아니오")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            checkPermissionsAndStart()
        } else {
            NSApp.terminate(nil)
        }
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
        if !axTrusted { missing.append("• 손쉬운 사용 (Accessibility)") }
        if !hidGranted { missing.append("• 입력 모니터링 (Input Monitoring)") }

        // 입력 모니터링이 빠졌으면 그쪽을 먼저 안내한다(이게 없으면 키보드를 아예 못 막음)
        let openListenEvent = !hidGranted
        let anchor = openListenEvent ? "Privacy_ListenEvent" : "Privacy_Accessibility"
        let openButtonTitle = openListenEvent ? "입력 모니터링 열기" : "손쉬운 사용 열기"

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "권한 \(missing.count)개가 더 필요해요"
        alert.informativeText = """
        시스템 설정 > 개인정보 보호 및 보안에서 아래 항목의 '닦아(ddak-a)'를 켜줘.

        \(missing.joined(separator: "\n"))

        켠 다음 닦아를 다시 실행하면 돼요.
        """
        alert.addButton(withTitle: openButtonTitle)
        alert.addButton(withTitle: "닫기")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }

    func startCleaning() {
        createOverlayWindows()

        if !startEventTap() {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "키보드를 막지 못했어요"
            alert.informativeText = "시스템 설정 > 개인정보 보호 및 보안에서 손쉬운 사용과 입력 모니터링 둘 다 '닦아'를 켜준 다음 다시 실행해줘."
            alert.addButton(withTitle: "확인")
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

    func createOverlayWindows() {
        closeOverlayWindows()

        // 🚨 2026-08-12 수정: NSScreen.screens는 호출할 때마다 다른 인스턴스를 돌려줄 수 있어서
        // `screen == NSScreen.screens.first` 같은 비교가 항상 false가 될 수 있다(= 글자·버튼이
        // 어느 화면에도 안 그려짐). 한 번만 받아서 그 배열만 쓴다.
        // 동시에, 마우스가 어느 모니터에 있든 탈출 버튼을 누를 수 있도록 모든 화면에 콘텐츠를 그린다.
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

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
    }

    func setupOverlayContent(in view: NSView, size: NSSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2

        let label = NSTextField(labelWithString: cleaningTitles[0])
        label.font = titleFont
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: centerX - 300, y: centerY + 10, width: 600, height: 70)
        view.addSubview(label)
        titleFields.append(label)

        let subLabel = NSTextField(labelWithString: "마우스·트랙패드는 자유롭게 움직여도 돼요")
        subLabel.font = subLabelFont
        subLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        subLabel.alignment = .center
        subLabel.frame = NSRect(x: centerX - 300, y: centerY - 30, width: 600, height: 24)
        view.addSubview(subLabel)

        let countdown = NSTextField(labelWithString: formattedTime(remainingSeconds))
        countdown.font = countdownFont
        countdown.textColor = NSColor.white.withAlphaComponent(0.85)
        countdown.alignment = .center
        countdown.frame = NSRect(x: centerX - 150, y: centerY - 80, width: 300, height: 30)
        view.addSubview(countdown)
        countdownFields.append(countdown)

        let button = OverlayButton(title: "다 닦았어요", target: self, action: #selector(finishButtonTapped))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: centerX - 90, y: centerY - 170, width: 180, height: 44)
        // 🚨 2026-08-12: 시스템 기본 버튼 배경이 하늘색 배경 위에서 옅게 렌더링돼 안 보이는 문제
        // 방지 — 흰 배경 + 진한 텍스트로 명시적으로 대비를 줌
        // (눌렀을 때 어두워지는 음영은 OverlayButton.mouseDown에서 처리)
        button.wantsLayer = true
        button.layer?.backgroundColor = buttonNormalColor
        button.layer?.cornerRadius = 10
        button.isBordered = false
        button.attributedTitle = buttonAttributedTitle
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
        createOverlayWindows()
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
        let dots = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.dotCount = (self.dotCount + 1) % cleaningTitles.count
            let title = cleaningTitles[self.dotCount]
            for field in self.titleFields {
                field.stringValue = title
            }
        }
        dots.tolerance = 0.15
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
        // 🚨 테스트 기간 안전장치(2026-08-12): dotTimer/countdownTimer가 무슨 이유로든 안 돌아도
        // 이 타이머는 독립적으로 돌아서 testSafetyLimitSeconds 뒤엔 무조건 풀어줌
        // (안전장치라 tolerance를 일부러 주지 않는다 — 한 번만 도는 타이머여서 전력에도 영향이 없다)
        let timer = Timer(timeInterval: testSafetyLimitSeconds, repeats: false) { [weak self] _ in
            self?.finishCleaning()
        }
        RunLoop.main.add(timer, forMode: .common)
        safetyTimer = timer

        // 🚨 2026-08-12: 최후의 보루 — Timer는 메인 런루프에 얹혀 있어서 앱이 멈추면 같이 멈춘다.
        // 런루프와 무관한 백그라운드 큐에서 시간을 재다가, 정상 종료가 안 됐으면 프로세스를 강제 종료한다.
        // 프로세스가 사라지면 이벤트탭도 함께 사라지므로 키보드는 무조건 복구된다.
        let deadline = DispatchTime.now() + testSafetyLimitSeconds + hardKillGraceSeconds
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
                    // 🚨 테스트 기간 안전장치(2026-08-12): Cmd+Option+Esc(강제 종료)만 예외로 통과시킴.
                    // 대부분의 키는 여기서 바로 걸러지므로 flags는 Esc일 때만 읽는다.
                    if event.getIntegerValueField(.keyboardEventKeycode) == kVKEscape {
                        let flags = event.flags
                        if flags.contains(.maskCommand) && flags.contains(.maskAlternate) {
                            return Unmanaged.passUnretained(event)
                        }
                    }
                    return nil

                case .flagsChanged:
                    // Command/Option 키의 상태 변화까지 통과시켜야 시스템이 "지금 Cmd+Opt이 눌려 있다"를
                    // 알 수 있다 — 이걸 삼키면 위의 탈출용 단축키가 실제로는 안 먹힐 수 있다.
                    // Shift·Control·CapsLock은 그대로 차단.
                    switch event.getIntegerValueField(.keyboardEventKeycode) {
                    case kVKCommand, kVKRightCommand, kVKOption, kVKRightOption:
                        return Unmanaged.passUnretained(event)
                    default:
                        return nil
                    }

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
