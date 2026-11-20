<p align="center">
  <img src="assets/icon/AppIcon-256.png" width="128" alt="닦아 앱 아이콘">
</p>

<a id="korean"></a>

# 닦아 (ddaka)

**한국어** · [English](#english) · [日本語](README.ja.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md)

> **기준일:** 2026-11-20
> **상태:** **v1.3 공개 배포 중** — [Releases](https://github.com/Hyunjin-Cho/ddaka/releases)에서 받을 수 있습니다 (앱·DMG 모두 Apple 공증 완료)

<!-- 🔒 2026-09-22 (PR #1 리뷰 F-3): 이 상태 줄과 아래 "v1.1부터는 …" 문장은 반드시 같이 움직인다.
     이 문서가 새 버전 동작을 현재형으로 안내하는데 Releases 에 그 버전이 없으면, 받아서 써 본
     사람에게는 "설명대로 안 된다"가 된다. 다음 버전을 준비할 때도 같은 순서로 — 릴리스 전까지는
     상태 줄에 "· vX.Y 준비 중"을 붙여 두고, 올리는 날 떼고 올린다.
     2026-11-20 (#36 · #39): 이름을 ddaka 로 바꾸며 v1.3 파일을 내려 두어 지금은 받을 앱이 없다 → 상태 줄을 "새 버전 준비 중"으로 바꿨다
     (버전 번호는 오너가 정한다 — v1.3 태그가 이미 있어 release.sh 는 1.3 을 다시 못 낸다). 새 버전을 올리는 날 "vX.Y 공개 배포 중"으로 되돌린다.
     2026-11-20 (#36): 오너 결정으로 v1.3 릴리스·태그를 지우고 새 이름(`ddaka-1.3.dmg`)으로 다시 냈다 → 상태 줄을 "v1.3 공개 배포 중"으로 되돌렸다. -->

<!-- 2026-11-18 오너: 한국어 설명은 존댓말(~습니다)로 쓴다 — 반말(~다) 문장을 바꿨다. 내용은 그대로다.
     홍보 글은 반말이어도 되지만 README 설명은 안 된다. 새 문장도 같은 말투로. -->

맥 키보드를 닦을 때 실수로 키가 눌려도 입력이 컴퓨터에 전달되지 않도록, 앱이 켜져 있는 동안
**키보드를 통째로 차단**하는 macOS 유틸리티입니다. **마우스와 트랙패드는 그대로 동작합니다.**

<p align="center">
  <b>macOS 12 (Monterey) 이상</b> · <b>Intel · Apple Silicon 모두 지원</b>
</p>

<p align="center">
  <img src="assets/screenshot.jpg" width="680" alt="실행 중 화면">
  <br>
  <sub>실행 중 화면 (v1.3) — 실행할 때마다 10가지 그림 중 하나가 연결된 <b>모든 모니터</b>를 덮습니다</sub>
</p>

<!-- 2026-11-18 (v1.3): 앱에 들어가는 그림 10장의 미리보기. 썸네일(assets/readme/themes/, 480px)은
     assets/themes/ 원본을 줄인 사본이라 그림을 바꾸면 같이 다시 만든다. 앱 번들에는 들어가지 않는다.
     폭 136 = GitHub README 칸(약 830px)에 5칸이 가로 스크롤 없이 들어가는 값. -->

<table align="center">
  <tr>
    <td align="center"><img src="assets/readme/themes/sunset.jpg" width="136" alt="노을"><br><sub>노을</sub></td>
    <td align="center"><img src="assets/readme/themes/beach.jpg" width="136" alt="바닷가"><br><sub>바닷가</sub></td>
    <td align="center"><img src="assets/readme/themes/busstop.jpg" width="136" alt="버스 정류장"><br><sub>버스 정류장</sub></td>
    <td align="center"><img src="assets/readme/themes/rain.jpg" width="136" alt="비 오는 날"><br><sub>비 오는 날</sub></td>
    <td align="center"><img src="assets/readme/themes/walk.jpg" width="136" alt="산책"><br><sub>산책</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/readme/themes/autumn.jpg" width="136" alt="가을"><br><sub>가을</sub></td>
    <td align="center"><img src="assets/readme/themes/night.jpg" width="136" alt="별똥별"><br><sub>별똥별</sub></td>
    <td align="center"><img src="assets/readme/themes/nap.jpg" width="136" alt="낮잠"><br><sub>낮잠</sub></td>
    <td align="center"><img src="assets/readme/themes/lookup.jpg" width="136" alt="올려다보기"><br><sub>올려다보기</sub></td>
    <td align="center"><img src="assets/readme/themes/snow.jpg" width="136" alt="눈"><br><sub>눈</sub></td>
  </tr>
</table>

## 설치

1. [Releases](https://github.com/Hyunjin-Cho/ddaka/releases)에서 `.dmg`를 받습니다
2. 열리는 창에서 **`닦아`를 `Applications` 폴더로 드래그**합니다
3. 응용 프로그램 폴더에서 실행합니다

**예전 `ddak-a` 를 쓰고 계셨다면** — v1.3부터 영어 이름이 `ddak-a` 에서 `ddaka` 로 바뀌어 새 앱이 예전 앱을 덮어쓰지 않습니다. 응용 프로그램 폴더의 **예전 `ddak-a` 를 휴지통에 버린 뒤** 새 앱을 옮겨 주세요. 권한(손쉬운 사용 · 입력 모니터링)이 꺼져 있으면 앱이 켜는 곳을 알려 드립니다.

> ### ⚠️ 반드시 응용 프로그램 폴더로 옮긴 뒤 실행하세요
>
> macOS는 인터넷에서 받은 앱을 응용 프로그램 폴더 **밖**에서 실행하면, 매번 임시로 만든
> 다른 경로에 복사해서 실행합니다(App Translocation). **이 임시 경로에서 실행되면
> 손쉬운 사용·입력 모니터링 권한이 붙지 않습니다** — 권한을 켜도 다음 실행 때 다시 꺼져 있습니다.
>
> 응용 프로그램 폴더로 **직접 옮기면** 이 동작이 풀립니다. 앱을 다운로드 폴더나 바탕화면에
> 꺼내 둔 채로 쓰면 권한이 영영 붙지 않습니다.
>
> v1.1부터는 앱이 이 상태를 스스로 알아채고, **권한을 묻기 전에** 안내하고 종료합니다.

<!-- 🚨 2026-09-22 정정: 위 문단에 원래 "손쉬운 사용·입력 모니터링 권한은 앱의 경로를 함께
     기억하기 때문에"라고 적혀 있었다. 그건 기전 단정이고 1차 근거가 없다 — macOS 권한 DB가
     무엇으로 앱을 식별하는지는 확인하지 못했다. 관측된 사실("임시 경로에서 실행되면 권한이
     붙지 않는다")까지만 남긴다. 같은 문장이 release.sh 주석에도 있었고 함께 고쳤다. -->

<!-- 🧪 2026-09-22 실측 (macOS 27.0, 공증·티켓 부착된 v1.1 빌드로 오너가 직접 확인).
     위 문단을 쓸 때 몰랐던 것 세 가지가 이날 갈렸다. 다시 파기 전에 여기부터 읽을 것.

     ① App Translocation 이 걸리는 조건이 갈렸다
        · 내려받은 DMG 를 열어 그 안에서 바로 실행  → 걸리지 않는다 (2회 확인. Gatekeeper
          승인 전후 모두, 앱이 /Volumes/... 에서 그대로 돌았고 AppTranslocation 디렉터리가
          만들어지지도 않았다)
        · 앱을 다운로드 폴더에 꺼내 두고 실행        → 걸린다
          (/private/var/folders/.../AppTranslocation/<UUID>/d/ 에서 돌았다)
        → 그래서 이 안내는 "DMG 에서 바로 실행하지 마라"보다 **"응용 프로그램 폴더가 아닌
          곳에 꺼내 두고 쓰지 마라"** 가 정확하다. 위 문단을 그렇게 고쳤다.

     ② 권한은 경로로 따라가지 않는다 — 번들 ID 와 서명이다
        /Applications 의 사본과 저장소 빌드본은 경로가 다른데도 권한을 다시 묻지 않았다.
        두 앱의 지정 요구(designated requirement)가 동일하고 거기에 경로가 한 글자도 없다:
          identifier "com.vismotive.ddaka" and anchor apple generic and ... leaf[subject.OU] = "6RH6FXY82P"
        → v1.0 사용자가 v1.1 로 올려도 권한이 유지된다. (TCC 내부가 정확히 이 요구를 쓰는지까지는
          확인하지 못했다. 확인된 것은 "경로가 기준이 아니다"까지다.)

     ③ 안내창을 띄워 둔 채 앱을 옮겨 실행하면 아무 반응이 없다
        LSMultipleInstancesProhibited 때문에 두 번째 실행이 막히고, 임시 경로에서 돌던
        인스턴스가 앞으로 나온다. 화면에 이미 그 창이 떠 있으므로 사용자 눈에는 "아무 일도
        일어나지 않는다"로 보인다. 그래서 안내 문구에 "확인 -> 종료 -> 옮기기" 순서를 넣었다
        (main.swift 의 translocatedBody). 문구는 함정을 줄이는 것이지 없애지는 못한다 —
        없애려면 안내 중 백그라운드 전환 시 자동 종료 같은 동작 변경이 필요하고, 그건 넣지 않았다. -->

첫 실행 때 **손쉬운 사용**과 **입력 모니터링** 권한을 요청합니다. 둘 다 있어야 키보드를 막을 수 있습니다.

## 동작 방식

1. 앱 실행 → "닦아 실행할까요?" 확인
2. 권한 확인 — **손쉬운 사용** + **입력 모니터링** 두 가지가 필요 (없으면 앱이 직접 요청합니다)
3. 연결된 **모든 모니터**를 그림 한 장으로 덮고 카운트다운 시작 — 그림은 실행할 때마다 10가지 장면 중 하나가 무작위로 나옵니다(v1.3)
4. 종료 조건 (셋 중 먼저 오는 것)
   - "다 닦았어요" 버튼 클릭 → 즉시 종료
   - 3분 카운트다운 종료 → 자동 종료
   - **Cmd + Shift + 9 (⌘⇧9)** → 앱이 직접 감지해 즉시 종료

## 단축키 하나로 켜고 끄기 (선택)

macOS에 기본으로 들어 있는 **단축어** 앱에 키보드 단축키를 걸면, 아이콘을 누르지 않고 닦아를 켤 수 있습니다.
그 키를 **⌘⇧9** 로 걸면 켜는 키와 끄는 키가 같아집니다 — **⌘⇧9 하나만 기억하면 됩니다.**

macOS 기본 앱 '단축어' 검색 (보라색배경 아이콘)
1) 플러스(+) 눌러서 새 단축어를 만들면 아래 무엇을 추가할 지 물어봅니다.
2) 아래 챗에서 "ddaka 앱 열기" 로 입력하면 찾아줍니다. (닦아가 설치되어 있어야 합니다.)
3) 2번까지 완료 됐다면, 단축키 클릭 후 상단에 있는 edit 클릭.
4) 그러면 새로운 창이 열리는데 그 새로운 창 우측 상단에 세부사항(ⓘ) 클릭.
5) 거기 아래 '키보드 단축키 추가' 에서 ⌘⇧9 를 눌러 주세요. 실제로 단축키에선 ⌘⇧( 이렇게 보입니다.
6) 창을 닫으시고 실행.

이제 **⌘⇧9** → 확인창에서 **예** → 청소 시작, 청소 중 **⌘⇧9** → 종료.

- 청소 중에 누른 ⌘⇧9 는 닦아가 먼저 받습니다. 단축어가 닦아를 다시 켜는 일은 없습니다
  (macOS 27.0 · 단축어 10.0 에서 실행 기록으로 확인. 단축어 앱은 macOS 12부터 있지만 그 아래 버전은 확인하지 못했습니다)
- 다른 키를 걸어도 켜는 건 되지만, **끄는 키는 언제나 ⌘⇧9** 입니다

<!-- 2026-09-25 오너 결정: 감사 문구를 절 맨 위 굵은 글씨에서 절 끝 인용 박스로 옮기고, 무엇을 제안했는지 붙였다.
     영어 절에도 같은 문구를 넣었다. 카페 주소 inmacbook = 맥쓰사는 네이버 카페 정보 API(mobileCafeName)로 확인. -->

> 💡 이 방법은 네이버 카페 [맥쓰사 (맥 쓰는 사람들)](https://cafe.naver.com/inmacbook)의 **봄물결**님이 제안해 주셨습니다. 감사합니다!

## 차단 범위

<!-- 🧪 2026-09-23 실기로 두 줄 추가 (리뷰 N-1 · N-3) — 오너 · macOS 27.0 · Mac Studio + Magic Keyboard with Touch ID · v1.2.
     통합 로그로 확정한 것:
     - Touch ID 키는 키보드 이벤트가 아니라 biometrickitd(`touchIDButtonPressed`)가 받는다 → 이벤트 탭 밖이고, macOS 의 정상 동작이다.
       한 번 → loginwindow `lockScreenImmediateFromTouchIDPress`(잠금). 0.6초 안에 세 번 → UniversalAccessControl(「손쉬운 사용 단축키」 창 + 음성).
       잠긴 동안에도 닦아는 계속 돌았고, 잠금을 푼 뒤 버튼으로 정상 종료했다(`tapReenabled=0`).
     - 🌐(fn)은 flagsChanged 로 들어와 탭이 통과시킨다(⌘⇧9 판정을 위해 조합키를 통과시키는 설계 — main.swift `.flagsChanged` 분기).
       🌐 를 받아쓰기로 쓰는 맥에서 "Dictation Hotkey start triggered" 바로 다음에 "Dictation did not start because there is
       bottom line input" — 받아쓰기는 시작 단계에서 끝났다. 🌐 를 입력 소스 전환·이모지로 쓰는 맥은 아직 확인하지 않았다. -->

| 대상 | 차단 여부 |
|---|---|
| 내장 키보드 | 차단 |
| 블루투스·USB 외장 키보드 | 차단 |
| 밝기·볼륨 등 미디어 키 | 차단 |
| Touch ID 키 | **통과 — macOS 가 처리하는 정상 동작.** 한 번 누르면 화면이 잠기고, 빠르게 세 번 누르면 「손쉬운 사용 단축키」 창이 뜹니다. 잠금을 풀면 청소 화면이 그대로 이어집니다 |
| 🌐(fn) 키 | **통과** — 청소 화면에는 입력 칸이 없어서 그대로 지나갑니다 |
| Cmd + Shift + 9 (⌘⇧9) | 앱이 감지해 **즉시 종료** (다른 앱에는 전달하지 않음) |
| 마우스 · 트랙패드 | 차단하지 않음 |

## 안전장치

키보드를 막는 앱이라 "풀리지 않는 상태"가 가장 위험합니다. 그래서 서로 독립적인 장치를 겹쳐 두었습니다.

- 3분 카운트다운이 끝나면 정상 종료합니다
- 카운트다운과 **별개로 도는** 안전 타이머가 190초에 한 번 더 종료를 시도합니다
- 위 타이머마저 실패할 경우를 대비해, **앱의 메인 로직과 무관한 백그라운드**에서 195초를 잰 뒤
  프로세스를 강제 종료합니다. 프로세스가 사라지면 키보드 차단도 함께 사라집니다
- 탈출 버튼을 **모든 모니터에** 띄웁니다 (마우스가 어느 화면에 있든 누를 수 있도록)
- 화면이 작아도 탈출 버튼이 잘리지 않도록 배치를 비례 축소합니다 (모니터를 여럿 쓰면서 작은
  보조 화면이 섞이는 구성 대비)
- **두 번 실행되지 않도록 막아 두었습니다.** 차단하는 앱이 둘이면 탈출 단축키를 눌러도 하나만 꺼지고
  나머지가 계속 막기 때문입니다. macOS 27에서 동작을 확인했고 그 아래 버전은 확인하지 못했습니다 —
  설령 막히지 않더라도 위의 자동 해제 장치들이 각 인스턴스마다 그대로 돌아갑니다

## 문제가 생겼을 때 (로그)

<!-- 2026-09-23 (#10) 신설. 종료 이유 값은 main.swift 의 FinishReason 과 짝이다 — 한쪽만 바꾸지 말 것. -->

v1.2부터 닦아는 청소가 **어떻게 끝났는지**를 macOS 로그에 남깁니다. 키보드가 늦게 풀렸거나
이상하게 끝났다면, 터미널에서 아래를 실행해 결과를 [이슈](https://github.com/Hyunjin-Cho/ddaka/issues)에
붙여 주시면 원인을 빨리 찾을 수 있습니다.

```bash
/usr/bin/log show --last 1h --predicate 'subsystem == "com.vismotive.ddaka"'
```

- `reason=` 뒤가 종료 이유입니다 — `done-button`(버튼) · `countdown`(3분) · `shortcut`(⌘⇧9) ·
  `safety-timer`(190초 안전 타이머) · `screens-gone`(화면이 모두 사라짐)
- 195초 강제 종료가 동작했다면 `hard kill` 이 남습니다
- v1.3부터 시작 줄에 `theme=` (그날 나온 그림의 이름)과 `art=` (그림을 읽었는지 — `false` 면 하늘색 바탕으로 물러난 것)가 함께 남습니다
- 🔒 **키 입력 내용은 기록하지 않습니다.** 남는 것은 시작·종료, 종료 이유, 권한 상태 같은 앱의 동작뿐입니다

## 직접 빌드하기

직접 빌드하는 방법, Apple 공증을 거친 배포본을 만드는 방법, 폴더 구조는 [`docs/BUILDING.md`](docs/BUILDING.md)에 있습니다.

<!-- 2026-11-18 (#23): 「빌드」·「외부 배포 (Apple 공증)」·「구조」 절을 docs/BUILDING.md 로 글 그대로 옮겼다 —
     README 는 사용자용만 남긴다(해외 홍보를 앞두고 오너 "공개 폴더 정리"). -->

## 표시 언어

맥의 시스템 언어를 따라 자동으로 바뀝니다. 앱 안에서 고르는 설정은 없습니다.

정확히는 **시스템 설정의 "선호하는 언어" 목록에서, 이 앱이 지원하는 언어 중 가장 위에 있는 것**을
씁니다. 1순위가 지원하지 않는 언어(예: 프랑스어)여도 2순위가 한국어면 한국어로 나옵니다.

| 시스템 언어 | 표시 |
|---|---|
| 한국어 | 한국어 |
| English | 영어 |
| 日本語 | 일본어 |
| 简体中文 (중국 본토·싱가포르) | 중국어 간체 |
| 繁體中文 (대만·홍콩·마카오) | 중국어 번체 |
| 지원 언어가 목록에 하나도 없을 때 | 영어 |

번체 중국어 중 언어를 홍콩·마카오로 둔 경우에는, 안내에 나오는 macOS 설정 이름을 홍콩 표기(私隱與保安 · 輸入監察)로 보여 줍니다.

문구는 `.lproj` 리소스가 아니라 소스 안 `L()` 함수에 5개 언어를 나란히 적는 방식입니다.
문구를 추가할 때 한 언어라도 빠뜨리면 **빌드가 실패**하므로 누락될 수 없습니다.

## 요구 사항

- **macOS 12 (Monterey) 이상**
  — 내 맥 버전은 화면 왼쪽 위 사과 메뉴 → **이 Mac에 관하여** 에서 볼 수 있습니다
- **Intel · Apple Silicon 모두 지원**
  — 두 아키텍처가 한 앱에 함께 들어 있는 유니버설 바이너리라, 맥 종류에 따라 다른 파일을
  받을 필요가 없습니다. 받은 앱이 알아서 그 맥에 맞는 쪽으로 실행됩니다
- 손쉬운 사용(Accessibility) 권한
- 입력 모니터링(Input Monitoring) 권한 — 키 입력을 가로채려면 손쉬운 사용과 **별도로** 필요합니다

> 배포본에서 실제로 확인한 값입니다 — 두 아키텍처 모두 최소 버전 `12.0`, 아키텍처 `x86_64 arm64`.
> 다만 **개발·검증은 macOS 27에서 했고, 12~26 실기기에서는 확인하지 못했습니다.**

## 라이선스

[MIT](LICENSE)

청소 화면 글꼴은 모두 SIL Open Font License 1.1 을 따르며, 앱에는 화면에 나오는 글자만 남긴 서브셋이 들어갑니다. 출처와 다시 만드는 법은 [`assets/fonts/README.md`](assets/fonts/README.md)에 있습니다.

- 한국어·영어 — 고운돋움(Gowun Dodum, © 2021 The Gowun Dodum Project Authors) — [`OFL-GowunDodum.txt`](assets/fonts/OFL-GowunDodum.txt)
- 일본어 — Klee One(© 2020 The Klee Project Authors) — [`OFL-KleeOne.txt`](assets/fonts/OFL-KleeOne.txt)
- 중국어 간체 — LXGW WenKai(霞鹜文楷, © 2021-2026 LXGW)를 바탕으로 한 서브셋. 원본의 예약된 글꼴 이름 때문에 앱 안에서는 "Ddaka Kai SC" 라는 이름을 씁니다 — [`OFL-LXGWWenKai.txt`](assets/fonts/OFL-LXGWWenKai.txt)
- 중국어 번체 — LXGW WenKai TC(霞鶩文楷 TC, © 2024 The LXGW WenKai Project Authors) — [`OFL-LXGWWenKaiTC.txt`](assets/fonts/OFL-LXGWWenKaiTC.txt)

---

<a id="english"></a>

<p align="center">
  <img src="assets/icon/AppIcon-256.png" width="128" alt="ddaka app icon">
</p>

# ddaka (닦아) — English

[한국어](#korean) · **English** · [日本語](README.ja.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md)

> **As of:** 2026-11-20
> **Status:** **v1.3 is out** — get it from [Releases](https://github.com/Hyunjin-Cho/ddaka/releases) (both the app and the DMG are notarized by Apple)

A macOS utility that **blocks the whole keyboard** while it runs, so keys you press by accident
while wiping your Mac's keyboard never reach the computer. **Your mouse and trackpad keep working.**

The name 닦아 (*ddaka*) is Korean for "wipe it".

<p align="center">
  <b>macOS 12 (Monterey) or later</b> · <b>Intel and Apple Silicon</b>
</p>

<p align="center">
  <img src="assets/screenshot.jpg" width="680" alt="ddaka while running">
  <br>
  <sub>While running (v1.3) — each launch, one of 10 illustrations covers <b>every connected display</b></sub>
</p>

<!-- 2026-11-18 (v1.3): preview of the 10 illustrations; see the comment above the Korean table. -->

<table align="center">
  <tr>
    <td align="center"><img src="assets/readme/themes/sunset.jpg" width="136" alt="Sunset"><br><sub>Sunset</sub></td>
    <td align="center"><img src="assets/readme/themes/beach.jpg" width="136" alt="Beach"><br><sub>Beach</sub></td>
    <td align="center"><img src="assets/readme/themes/busstop.jpg" width="136" alt="Bus stop"><br><sub>Bus stop</sub></td>
    <td align="center"><img src="assets/readme/themes/rain.jpg" width="136" alt="Rainy day"><br><sub>Rainy day</sub></td>
    <td align="center"><img src="assets/readme/themes/walk.jpg" width="136" alt="Walk"><br><sub>Walk</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/readme/themes/autumn.jpg" width="136" alt="Autumn"><br><sub>Autumn</sub></td>
    <td align="center"><img src="assets/readme/themes/night.jpg" width="136" alt="Shooting stars"><br><sub>Shooting stars</sub></td>
    <td align="center"><img src="assets/readme/themes/nap.jpg" width="136" alt="Nap"><br><sub>Nap</sub></td>
    <td align="center"><img src="assets/readme/themes/lookup.jpg" width="136" alt="Looking up"><br><sub>Looking up</sub></td>
    <td align="center"><img src="assets/readme/themes/snow.jpg" width="136" alt="Snow"><br><sub>Snow</sub></td>
  </tr>
</table>

## Install

1. Download the `.dmg` from [Releases](https://github.com/Hyunjin-Cho/ddaka/releases)
2. In the window that opens, **drag `닦아` onto the `Applications` folder**
3. Launch it from your Applications folder

**If you were using the old `ddak-a`** — from v1.3 the English name is `ddaka` instead of `ddak-a`, so the new app does not replace the old one. **Move the old `ddak-a` in your Applications folder to the Trash first**, then move the new app in. If the permissions (Accessibility · Input Monitoring) are off, the app shows you where to turn them on.

> ### ⚠️ Move it to Applications before you run it
>
> When you run an app downloaded from the internet from **outside** the Applications folder,
> macOS runs it from a fresh temporary copy each time (App Translocation). **An app running from
> that temporary path never keeps its Accessibility and Input Monitoring permissions** — you turn
> them on, and the next launch has them off again.
>
> Moving it into Applications **yourself** releases that behaviour. If you leave the app sitting in
> Downloads or on the Desktop, the permissions will never stick.
>
> Since v1.1 the app notices this itself and tells you **before asking for any permission**, then quits.

On first launch it asks for **Accessibility** and **Input Monitoring**. It needs both to block the keyboard.

## How it works

1. Launch → "Start ddaka?" confirmation
2. Permission check — **Accessibility** + **Input Monitoring** (the app requests them itself if missing)
3. Covers **every connected display** with a full-screen illustration and starts the countdown — a different one of 10 scenes is picked at random each launch (v1.3)
4. It ends on whichever comes first:
   - Clicking **"Done"** → quits immediately
   - The 3-minute countdown finishing → quits automatically
   - **Cmd + Shift + 9 (⌘⇧9)** → the app detects it itself and quits immediately

## Start and stop with one shortcut (optional)

<!-- 2026-09-23: new — answers a user suggestion ("start it with a shortcut instead of clicking the icon,
     and press the same key again to release") with the Shortcuts app instead of changing the app.
     Evidence and the reason the app itself doesn't listen for a global shortcut: see the comment in the
     Korean section above. Menu names verified in Shortcuts 10.0 on macOS 27.0 (the app's own string tables). -->

Give the built-in **Shortcuts** app a keyboard shortcut and you can start ddaka without clicking its icon.
Make that shortcut **⌘⇧9** and the start key and the quit key become the same — **⌘⇧9 is all you need to remember.**

1. In **Shortcuts**, click **＋** to make a new shortcut
2. Add the **Open App** action and choose **닦아** as the app
3. **Shortcut Details** (ⓘ) → **Add Keyboard Shortcut** → press **⌘⇧9**

Now **⌘⇧9** → **Start** in the confirmation → cleaning starts; **⌘⇧9** while cleaning → it quits.

- A ⌘⇧9 pressed during cleaning reaches ddaka first, so Shortcuts never launches it again
  (confirmed from the run logs on macOS 27.0 with Shortcuts 10.0. Shortcuts has shipped since macOS 12, but
  earlier versions have not been verified)
- Any other key can start it too, but **the quit key is always ⌘⇧9**

<!-- 2026-09-25: credit added to mirror the Korean section (owner decision). -->

> 💡 This tip was suggested by **봄물결 (Bommulgyeol)** on the Korean Naver cafe [(맥쓰사)](https://cafe.naver.com/inmacbook). Thank you!

## What gets blocked

<!-- 2026-09-23: the Touch ID and 🌐 (fn) rows come from a real-device check on macOS 27.0 (review N-1 · N-3).
     The log evidence is in the comment above the Korean table. -->

| Input | Blocked? |
|---|---|
| Built-in keyboard | Blocked |
| Bluetooth / USB external keyboards | Blocked |
| Media keys (brightness, volume, …) | Blocked |
| Touch ID key | **Passes through — macOS handles it, which is normal.** One press locks the screen; three quick presses open the Accessibility Shortcuts panel. Unlock and the cleaning screen carries on |
| 🌐 (fn) key | **Passes through** — the cleaning screen has no text field, so the press simply goes by |
| Cmd + Shift + 9 (⌘⇧9) | Caught by the app to **quit immediately** (never passed to other apps) |
| Mouse / trackpad | Not blocked |

## Safety nets

For an app that blocks your keyboard, the dangerous failure is "it never lets go". So several
independent mechanisms are layered on top of each other.

- The 3-minute countdown ends with a normal quit
- A safety timer that runs **independently of the countdown** tries again at 190 seconds
- In case even that timer fails, a **background watchdog unrelated to the app's main logic** counts
  to 195 seconds and kills the process. When the process is gone, so is the keyboard block
- The escape button is shown on **every display**, so it is reachable wherever your mouse is
- The layout scales down proportionally so the escape button is never clipped on small screens
- **A second instance is prevented.** With two blockers running, the escape shortcut would quit only
  one and the other would keep blocking. Verified on macOS 27; not verified below that — and even if
  it were not prevented, every automatic release above still runs per instance

## If something goes wrong (logs)

Since v1.2, ddaka writes **how each cleaning session ended** to the macOS log. If the keyboard was
released late or something looked wrong, run this in Terminal and attach the output to an
[issue](https://github.com/Hyunjin-Cho/ddaka/issues):

```bash
/usr/bin/log show --last 1h --predicate 'subsystem == "com.vismotive.ddaka"'
```

- The word after `reason=` is why it ended — `done-button` · `countdown` (3 minutes) · `shortcut` (⌘⇧9) ·
  `safety-timer` (the 190-second safety timer) · `screens-gone` (every display disappeared)
- If the 195-second hard stop fired, you will see `hard kill`
- Since v1.3 the start line also carries `theme=` (which illustration was shown) and `art=` (whether it loaded — `false` means it fell back to the plain sky-blue background)
- 🔒 **Keystrokes are never logged.** Only what the app itself did is recorded — start and end,
  the end reason and permission status

## Building from source

How to build it yourself, how to make a notarized release, and the project layout are in [`docs/BUILDING.md`](docs/BUILDING.md#english).

## Display language

The app follows your Mac's system language automatically. There is no in-app setting.

More precisely, it uses **the highest entry in your system's "Preferred Languages" list that this app
actually supports**. If your first choice is a language it does not support (French, say) but Korean
is second, you get Korean.

| System language | Shown as |
|---|---|
| 한국어 | Korean |
| English | English |
| 日本語 | Japanese |
| 简体中文 (mainland China, Singapore) | Simplified Chinese |
| 繁體中文 (Taiwan, Hong Kong, Macau) | Traditional Chinese |
| None of the supported languages in the list | English |

Traditional Chinese users whose language is set to Hong Kong or Macau see the macOS setting names in the app's instructions in their Hong Kong form (私隱與保安 · 輸入監察).

Strings are not `.lproj` resources; all five languages sit side by side in an `L()` call in the
source. Adding a string with a language missing **fails the build**, so none can be forgotten.

## Requirements

- **macOS 12 (Monterey) or later**
  — check yours under  → **About This Mac**
- **Intel and Apple Silicon**
  — one universal binary contains both architectures, so there is no separate download per Mac
- Accessibility permission
- Input Monitoring permission — intercepting key input needs this **separately** from Accessibility

> These are verified against the shipping build: minimum version `12.0` and architectures
> `x86_64 arm64` for both slices. Note that **development and testing were done on macOS 27; 12
> through 26 have not been verified on real hardware.**

## License

[MIT](LICENSE)

The cleaning-screen fonts are all under the SIL Open Font License 1.1. The app ships subsets with only the characters the screen shows. Sources and how to rebuild them are in [`assets/fonts/README.md`](assets/fonts/README.md#english).

- Korean and English — Gowun Dodum (© 2021 The Gowun Dodum Project Authors) — [`OFL-GowunDodum.txt`](assets/fonts/OFL-GowunDodum.txt)
- Japanese — Klee One (© 2020 The Klee Project Authors) — [`OFL-KleeOne.txt`](assets/fonts/OFL-KleeOne.txt)
- Simplified Chinese — a subset based on LXGW WenKai (霞鹜文楷, © 2021-2026 LXGW). Because the original declares Reserved Font Names, it is named "Ddaka Kai SC" inside the app — [`OFL-LXGWWenKai.txt`](assets/fonts/OFL-LXGWWenKai.txt)
- Traditional Chinese — LXGW WenKai TC (霞鶩文楷 TC, © 2024 The LXGW WenKai Project Authors) — [`OFL-LXGWWenKaiTC.txt`](assets/fonts/OFL-LXGWWenKaiTC.txt)
