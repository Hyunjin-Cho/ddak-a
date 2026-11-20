<a id="korean"></a>

# 닦아 — 빌드와 배포

**한국어** · [English](#english)

> **기준일:** 2026-11-18

<!-- 2026-11-18 (#23): README 의 「빌드」·「외부 배포 (Apple 공증)」·「구조」 절을 글 그대로 옮겼다. 상대 경로 링크만 ../ 를 붙였다. -->

사용법은 [README](../README.md)에 있습니다. 이 문서는 직접 빌드하거나 배포본을 만드는 분을 위한 것입니다.

## 빌드

```bash
bash build.sh
```

Intel + Apple Silicon 유니버설 바이너리로 빌드하고, `.app` 번들로 묶은 뒤 코드 서명까지 합니다.
서명에 쓸 인증서는 환경변수로 바꿀 수 있습니다.

```bash
DDAKA_SIGN_IDENTITY="Developer ID Application: ..." bash build.sh
```

> 인증서 없이 ad-hoc으로 서명하면 **빌드할 때마다 앱의 신원이 바뀌어** macOS가 다른 앱으로 인식하고,
> 손쉬운 사용·입력 모니터링 권한이 매번 풀립니다. 정식 인증서로 서명해야 권한이 유지됩니다.

### 화면 확인 — 디버그 빌드 전용 (2026-11-18)

청소 화면은 키보드를 막는 화면이라 실행해서 보기 어렵습니다. 디버그 빌드(`swift build`)에는 키보드를 막지 않고 확인하는 길이 두 개 있습니다. 배포 빌드에는 들어가지 않습니다.

```bash
# 청소 화면 → PNG (화면 크기 6가지: 1440×900 · 1920×1080 · 2560×1440 · 800×500 · 1080×1920 · 1024×768 — 4:3 은 2026-11-20 추가)
DDAKA_ASSETS=assets DDAKA_LANG=ko .build/debug/ddaka --preview <폴더> [장면 id ...]

# 안내창 문구(권한 · 임시 경로 · 키 차단 실패)를 언어별로 출력
DDAKA_LANG=zh-hant-hk .build/debug/ddaka --strings
```

- `DDAKA_LANG`: `en` · `ko` · `ja` · `zh-hans` · `zh-hant` · `zh-hant-hk`(번체 + 홍콩 설정 이름).
- 2560×1440 은 그림 원본 크기입니다. 그림이 잘리지 않고 1:1 로 깔리므로 글자 자리를 검사할 때 씁니다.
- 배치가 여백 밖으로 나가거나 글자 묶음과 알약이 겹치면 `⚠️` 줄이 찍힙니다.

## 외부 배포 (Apple 공증)

> **이 절은 저장소를 직접 빌드해 배포하려는 경우를 위한 것입니다.** 앱을 쓰기만 하신다면 위 「설치」만
> 보시면 됩니다. 여기 적힌 절차는 **각자의 Developer ID 인증서와 Apple 계정으로** 진행하는 것이며,
> 이 저장소에는 인증서나 비밀번호가 들어 있지 않습니다(둘 다 각자의 macOS 키체인에만 있습니다).

다른 사람에게 배포하려면 Developer ID 서명뿐 아니라 Apple 공증과 티켓 부착까지 끝내야 합니다.
비밀번호는 저장소나 스크립트에 넣지 않고 macOS 키체인에 보관합니다.

### 1. 최초 한 번 — 공증 인증 정보를 키체인에 저장

[Apple 계정 페이지](https://account.apple.com/)의 **로그인 및 보안 > 앱 전용 암호**에서 공증용 암호를 하나 만듭니다.
아래 명령은 그 앱 전용 암호를 화면에 표시하지 않고 안전하게 물어본 뒤 `ddaka-notary`라는 이름으로 저장합니다.

```bash
xcrun notarytool store-credentials "ddaka-notary" \
  --apple-id "본인의 Apple ID" \
  --team-id "6RH6FXY82P"
```

### 2. 설치 창을 만드는 도구 준비 (최초 한 번)

DMG 를 열었을 때 나오는 설치 창(배경 그림·아이콘 위치·창 크기)은 `dmgbuild` 로 만듭니다.
시스템 파이썬을 건드리지 않도록 프로젝트 전용 가상환경에 설치합니다.

```bash
python3 -m venv .tools/venv
.tools/venv/bin/python -m pip install dmgbuild
```

> 🔒 **`dmgbuild` 는 1.6.7 이상이어야 합니다.** macOS 26.2 에서 `.DS_Store` 에 `pBBk` 블롭이
> 들어 있으면 DMG 배경이 표시되지 않는 회귀가 있었는데(FB21405103), `dmgbuild` 1.6.7 이
> 그 블롭을 빼면서 해결됐습니다. 낮은 버전으로 만들면 **배경 없는 맨 창이 조용히 나갑니다** —
> 빌드는 성공하므로 눈으로 보기 전에는 모릅니다. `release.sh` 가 시작 전에 버전을 확인합니다.

> macOS 는 원래 이 설정을 Finder 에게 시켜서 만들지만, **macOS 27 에서는 Finder 의
> "배경 그림 지정"이 동작하지 않습니다** — 설정하면 오류 없이 무시되고, 읽으면 `-10000`
> 오류가 납니다(2026-09-22 실측). `dmgbuild` 는 Finder 를 거치지 않고 `.DS_Store` 를 직접
> 만들기 때문에 이 문제의 영향을 받지 않습니다.
>
> 창 구성은 `assets/dmg-settings.py` 에 있습니다. 아이콘 좌표는 배경 그림
> (`assets/dmg-background.swift`)의 화살표 위치와 같아야 합니다 — 한쪽만 고치면 어긋납니다.

### 3. 외부 배포본 만들기

```bash
bash release.sh
```

`release.sh`는 아래 단계를 모두 통과해야 `dist/` 안에 최종 `.dmg`를 만듭니다.

<!-- 2026-09-23 (#6·#7): 1번(작업 폴더 확인)·2번(공개된 버전 확인)·4번(이전 결과 옮겨 두기)·
     7번(소스 기록)을 더했다. -->

1. 작업 폴더가 깨끗한지 확인 — 커밋하지 않은 변경이나 추적하지 않는 새 파일이 있으면 멈춥니다
   (빌드 번호가 커밋 수라서, 섞인 채로 만들면 다른 소스가 같은 번호로 나갑니다)
2. 이미 공개된 버전인지 확인 — 로컬이나 `origin` 에 `v<버전>` 태그가 있으면 멈춥니다. 원격을 확인하지
   못해도(네트워크·인증) 멈춥니다 — 확인하지 못한 것을 "없다"로 치지 않습니다
3. 키체인 프로필·인증서·도구(`dmgbuild` 버전 포함)가 준비됐는지 확인 (여기까지 모두 긴 빌드 전에 걸러냅니다)
4. 같은 버전으로 먼저 만든 결과가 있으면 지우지 않고 `release-records/<버전>.prev-<시각>/` 으로 옮깁니다
5. Intel + Apple Silicon 유니버설 빌드
6. Developer ID 서명과 Hardened Runtime 적용
7. 어떤 소스로 빌드했는지 `release-records/<버전>/source.txt` 에 기록 — 빌드 도중 커밋·파일이 바뀌지
   않았는지, 빌드 번호가 커밋 수와 같은지 대조한 뒤에 남깁니다
8. 서명이 **제대로** 됐는지 단언 — Hardened Runtime · 신뢰 타임스탬프 · `get-task-allow` 없음
9. 디버그 심볼(dSYM)을 배포 바이너리와 UUID 대조 후 `release-records/` 에 보관
10. **앱** 공증 제출 → 승인 대기 → 티켓 부착 (제출 ID·로그도 함께 보관)
11. 응용 프로그램 폴더 바로가기를 넣은 **DMG** 생성
12. **DMG** 서명 → 공증 → 티켓 부착
13. Gatekeeper 실행 가능 여부 최종 확인
14. 배포물 SHA-256 을 `dist/*.dmg.sha256` 에 기록

> 급할 때는 `DDAKA_ALLOW_DIRTY=1 bash release.sh` 로 1번을 넘길 수 있습니다. 크게 경고하고, `source.txt` 에
> dirty 표시와 변경 목록·diff 해시를 남깁니다 — 그 커밋만으로는 재현되지 않는 빌드라는 표시입니다.
> 2번(태그 확인)에는 우회 스위치가 없습니다 — 넘어가는 길은 버전을 올리는 것뿐입니다.
> (2026-09-23 · #6·#7)

> 🔒 **`.dmg` 와 `.dmg.sha256` 을 함께 릴리스에 올립니다**(또는 릴리스 노트에 해시를 적습니다).
> 체크섬은 "받은 파일이 우리가 올린 그 파일인지" 사용자가 직접 대조하라고 만드는 값인데,
> `dist/` 도 `release-records/` 도 저장소에 올라가지 않으므로 **올려두지 않으면 우리만 보는 값**이
> 되어 아무 일도 하지 못합니다. 받은 쪽에서는 `shasum -c ddaka-v<버전>.dmg.sha256` 로 확인합니다.
> (2026-09-22 · PR #1 리뷰 F-4)

> `release-records/<버전>/` 에는 소스 기록(`source.txt` — 커밋·브랜치·빌드 번호·dirty 여부)·dSYM·
> 공증 로그·체크섬이 남습니다. `.build/` 밖에 두는 이유는 `swift package clean` 한 번에 날아가지
> 않게 하려는 것입니다 — dSYM 이 없으면 나중에 받은 크래시 리포트에 함수 이름이 안 나오고 주소만
> 남습니다. 이 폴더는 저장소에 올리지 않습니다. (소스 기록: 2026-09-23 · #6)
>
> 🔒 **기록은 덮어쓰지 않습니다.** 같은 버전으로 다시 돌리면(예: draft 단계의 재공증) 이전 기록은
> `release-records/<버전>.prev-<시각>/` 으로 옮겨지고, `dist/` 에 있던 이전 DMG·체크섬도 그 안의
> `dist/` 로 함께 옮겨집니다. 이미 `v<버전>` 태그가 붙은(= 공개된) 버전은 아예 다시 만들지 않습니다 —
> 다시 빌드한다고 사용자 손에 있는 바이너리와 짝이 맞는 dSYM 이 나온다는 보장이 없기 때문입니다.
> 다시 만들어야 하면 `Info.plist` 의 버전(`CFBundleShortVersionString`)을 올립니다. (2026-09-23 · #7)
<!-- 2026-11-18 (#20·#21) 예외 한 번: v1.3 은 홍보 전이고 받은 사람이 오너뿐이라 오너 결정으로 릴리스와 태그를 지우고 같은 버전으로 다시 냈다. 같은 날 오후(#25·#26) 오너 결정으로 한 번 더(두 번째 예외), 저녁(#31·#32)에 또 한 번(세 번째 예외). 근거·경위는 release.sh 의 태그 검사 주석. -->

> 앱과 DMG를 **둘 다** 공증합니다. 앱에만 티켓을 붙이면 DMG를 열 때 경고가 남고,
> DMG에만 붙이면 앱을 꺼내 옮겼을 때 검증이 약해집니다.

다른 키체인 프로필이나 서명 인증서를 쓸 때는 환경변수로 바꿀 수 있습니다.

```bash
DDAKA_NOTARY_PROFILE="다른-프로필" \
DDAKA_SIGN_IDENTITY="Developer ID Application: ..." \
bash release.sh
```

공식 안내: [Apple — Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

> **Mac App Store로는 배포할 수 없습니다.** App Store는 샌드박스가 필수인데,
> 이 앱이 쓰는 키 입력 가로채기(`CGEventTap`)와 입력 모니터링 권한은 샌드박스에서 동작하지 않습니다.
> Developer ID 직접 배포가 유일한 경로입니다.

## 구조

| 파일 | 역할 |
|---|---|
| `README.md` | 소개 · 설치 · 사용법 |
| `README.ja.md` · `README.zh-Hans.md` · `README.zh-Hant.md` | `README.md` 의 일본어 · 중국어 간체 · 중국어 번체판 (2026-11-18). `README.md` 를 고치면 같이 고칩니다 |
| `docs/BUILDING.md` | 이 문서 — 빌드 · 배포 · 구조 (2026-11-18 README 에서 옮김, #23) |
| `Sources/ddaka/main.swift` | 앱 로직 — 키보드 차단 · 창 · 타이머 · 청소 화면 배치 |
| `Sources/ddaka/Themes.swift` | 청소 화면 테마 — 장면 10개의 표(글자·버튼 자리, 글자색) · 그림·글꼴 읽기 (v1.3) |
| `Package.swift` | SPM 설정 |
| `Info.plist` | 번들 정보 |
| `build.sh` | 유니버설 빌드 + `.app` 패키징 + 코드 서명 |
| `release.sh` | 공증 + DMG 생성 + DMG 공증 + 티켓 부착 |
| `assets/icon/` | 앱 아이콘 — 원본 그림(테마와 같은 강아지·고양이 일러스트)과 결과물 (`AppIcon.icns` 가 빌드에 쓰입니다). 파일별 설명과 다시 만드는 법은 [`assets/icon/README.md`](../assets/icon/README.md) |
| `assets/icon/make-icon.sh` | 원본 그림을 잘라 `AppIcon.icns` 까지 다시 만드는 스크립트 (`assets/icon/make-icon.sh <출력폴더>` · 커밋된 파일은 덮어쓰지 않습니다) |
| `assets/themes/` | 청소 화면 그림 10장 (2560×1440 JPEG). 🔒 `Themes.swift` 의 표와 개수·이름이 같아야 합니다 — `build.sh` 가 대조합니다 |
| `assets/fonts/` | 청소 화면 글꼴 4종(한·영 고운돋움 · 일 Klee One · 간 Ddaka Kai SC = LXGW WenKai 서브셋 · 번 LXGW WenKai TC) — 앱이 쓰는 글자만 남긴 서브셋과 각 SIL OFL 1.1 원문. 출처·SHA-256·다시 만드는 법은 [`assets/fonts/README.md`](../assets/fonts/README.md) (2026-11-18) |
| `assets/fonts/make-subsets.sh` · `check-overlay-glyphs.swift` | 일·중 서브셋 만들기 · 청소 화면 문구의 글자가 서브셋에 다 있는지 검사(`build.sh` 가 빌드 때 돌리고, 빠지면 멈춥니다). 둘 다 앱에는 들어가지 않습니다 |
| `assets/screenshot.jpg` | README 용 실행 화면 |
| `assets/readme/themes/` | README 용 그림 10장 미리보기 (480px 썸네일 — `assets/themes/` 를 줄인 사본, 앱에는 들어가지 않습니다) |
| `assets/dmg-settings.py` | DMG 설치 창 구성 (배경·아이콘 위치·창 크기) |
| `assets/dmg-background.swift` | 설치 창 배경 그림을 그리는 스크립트 (`swift ... <출력폴더>`) |
| `assets/dmg-background.tiff` | 위 스크립트로 만든 실제 배경 (1x·2x 두 장. `tiffutil -cathidpicheck` 로 합칩니다) |

<!-- 🚨 2026-09-23 (#11): assets/icon 행 정정. 종전 "아이콘 원본과 변환 스크립트" 는 실제와 달랐다 —
     mask.swift 가 저장소에 없는 파일을 읽고 커밋된 것과 다른 이름으로 써서, 저장소만으로는 아이콘을
     다시 만들 수 없었다. 전체 과정은 make-icon.sh 와 assets/icon/README.md 에 있다. -->

> 🔒 **설치 창 관련 세 파일은 같이 움직입니다.** 배경 그림의 `W x H` 와 `dmg-settings.py` 의
> `window_rect` 가 같아야 하고(다르면 Finder 창에서 아래가 잘립니다), 아이콘 좌표와 배경의
> 화살표 위치도 같아야 합니다(다르면 화살표가 엉뚱한 곳을 가리킵니다).
> 배경을 다시 그렸으면 `.tiff` 까지 새로 만들어야 반영됩니다.

> `release-records/<버전>/` 에는 배포할 때마다 소스 기록(`source.txt`)·dSYM·공증 로그·체크섬이 쌓입니다.
> 같은 버전을 다시 돌리면 이전 것은 `release-records/<버전>.prev-<시각>/` 으로 옮겨져 남습니다.
> 저장소에는 올리지 않습니다(로컬 보관용).

---

<a id="english"></a>

# ddaka — Building and releasing

[한국어](#korean) · **English**

> **As of:** 2026-11-18

How to use the app is in the [README](../README.md#english). This document is for people who build it themselves or make a release.

## Build

```bash
bash build.sh
```

Builds a universal binary (Intel + Apple Silicon), wraps it in an `.app` bundle and code-signs it.
The signing identity can be overridden:

```bash
DDAKA_SIGN_IDENTITY="Developer ID Application: ..." bash build.sh
```

> With an ad-hoc signature (no certificate) **the app's identity changes on every build**, macOS sees
> a different app each time, and the Accessibility / Input Monitoring grants are dropped. A real
> certificate keeps the identity — and the permissions — stable.

### Checking the screens — debug builds only (2026-11-18)

The cleaning screen locks the keyboard, so it is hard to look at by running the app. A debug build (`swift build`) has two ways to check it without locking anything. Neither ships in the release build.

```bash
# Cleaning screen → PNG (six sizes: 1440×900 · 1920×1080 · 2560×1440 · 800×500 · 1080×1920 · 1024×768 — 4:3 added 2026-11-20)
DDAKA_ASSETS=assets DDAKA_LANG=ko .build/debug/ddaka --preview <folder> [scene id ...]

# Print the dialog strings (permissions · temporary path · key-block failure) for one language
DDAKA_LANG=zh-hant-hk .build/debug/ddaka --strings
```

- `DDAKA_LANG`: `en` · `ko` · `ja` · `zh-hans` · `zh-hant` · `zh-hant-hk` (Traditional Chinese with Hong Kong setting names).
- 2560×1440 is the art's native size: the picture is shown 1:1 without cropping, which is what to use when checking where text lands.
- A `⚠️` line is printed when something leaves the safe margin or the caption overlaps the button pill.

## Distributing it yourself (Apple notarization)

> **This section is for building and distributing from this repository.** If you only want to use the
> app, the [Install](#install) section is all you need. Everything here runs with **your own
> Developer ID certificate and Apple account**; no certificate or password is stored in this
> repository (both live only in your own macOS Keychain).

Shipping to other people needs Developer ID signing, Apple notarization and a stapled ticket.
Credentials go in the Keychain, never in the repo or a script.

### 1. One-time — store notarization credentials in the Keychain

Create an app-specific password at [account.apple.com](https://account.apple.com/) under
**Sign-In and Security > App-Specific Passwords**. The command below asks for it without echoing it
and saves it under the name `ddaka-notary`:

```bash
xcrun notarytool store-credentials "ddaka-notary" \
  --apple-id "your Apple ID" \
  --team-id "6RH6FXY82P"
```

### 2. One-time — the tool that builds the installer window

The installer window you see when opening the DMG (background art, icon positions, window size) is
produced by `dmgbuild`. Install it in a project-local virtualenv so the system Python stays untouched:

```bash
python3 -m venv .tools/venv
.tools/venv/bin/python -m pip install dmgbuild
```

> 🔒 **`dmgbuild` must be 1.6.7 or newer.** On macOS 26.2 a `pBBk` blob inside `.DS_Store` stopped the
> DMG background from showing (FB21405103); `dmgbuild` 1.6.7 fixed it by dropping that blob. An older
> version **silently ships a blank installer window** — the build still succeeds, so you only find out
> by looking. `release.sh` checks the version before it starts.

> macOS normally has Finder produce these settings, but **on macOS 27 Finder's "set background
> picture" does not work** — setting it is ignored without an error, and reading it returns `-10000`
> (measured 2026-09-22). `dmgbuild` writes `.DS_Store` directly without going through Finder, so it is
> unaffected.

### 3. Build the distributable

```bash
bash release.sh
```

`release.sh` only produces the final `.dmg` in `dist/` after every step below passes.

<!-- 2026-09-23 (#6, #7): added step 1 (clean working tree), step 2 (already-published version),
     step 4 (move previous results aside) and step 7 (source record). -->

1. Check the working tree is clean — it stops on uncommitted changes or untracked new files
   (the build number is the commit count, so mixed-in changes would ship different source under the same number)
2. Check the version is not already published — it stops if a `v<version>` tag exists locally or on `origin`,
   and it also stops if it cannot check the remote (network, auth): not being able to check never counts as "no tag"
3. Check the Keychain profile, certificate and tooling (including the `dmgbuild` version) — everything up to here runs **before** the long build
4. If an earlier run of the same version left results, move them — never delete them — to `release-records/<version>.prev-<timestamp>/`
5. Universal build (Intel + Apple Silicon)
6. Developer ID signature with Hardened Runtime
7. Record which source was built in `release-records/<version>/source.txt` — only after checking that
   neither the commit nor the files changed during the build and that the build number equals the commit count
8. Assert the signature is actually **correct** — Hardened Runtime, trusted timestamp, no `get-task-allow`
9. Match the dSYM's UUID against the shipping binary, then keep it in `release-records/`
10. Submit the **app** for notarization → wait → staple the ticket (submission ID and log are kept too)
11. Build the **DMG** with an Applications shortcut inside
12. Sign → notarize → staple the **DMG**
13. Final Gatekeeper assessment
14. Record the SHA-256 of the distributable in `dist/*.dmg.sha256`

> In an emergency, `DDAKA_ALLOW_DIRTY=1 bash release.sh` lets step 1 through. It warns loudly and marks
> `source.txt` as dirty, with the list of changes and a hash of the diff — a build the commit alone cannot
> reproduce. Step 2 (the tag check) has no override: bumping the version is the only way past it.
> (2026-09-23 · #6, #7)

> 🔒 **Upload the `.dmg` and the `.dmg.sha256` together** (or put the hash in the release notes). The
> checksum exists so people can verify that what they downloaded is what you uploaded — but neither
> `dist/` nor `release-records/` is committed, so if you do not upload it the value is one only you can
> see. On the receiving end: `shasum -c ddaka-v<version>.dmg.sha256`.

> `release-records/<version>/` keeps the source record (`source.txt` — commit, branch, build number, dirty
> or not), the dSYM, the notarization logs and the checksum. It lives outside `.build/` so that a single
> `swift package clean` cannot wipe it — without the dSYM, crash reports you receive later show bare
> addresses instead of function names. The folder is not committed. (source record: 2026-09-23 · #6)
>
> 🔒 **Records are never overwritten.** Re-running the same version (e.g. re-notarizing during the draft
> stage) moves the previous records to `release-records/<version>.prev-<timestamp>/`, and the previous DMG
> and checksum in `dist/` go into a `dist/` folder inside it. A version that already has a `v<version>` tag
> (i.e. is published) is not rebuilt at all — a rebuild is not guaranteed to produce a dSYM that matches the
> binary people already have. To rebuild, bump the version (`CFBundleShortVersionString`) in `Info.plist`.
> (2026-09-23 · #7)
<!-- 2026-11-18 (#20, #21) one-off exception: v1.3 had not been announced and only the owner had downloaded it, so by the owner's decision the release and tag were deleted and the same version was released again. The owner decided to do it once more that afternoon (#25, #26; second exception) and again that evening (#31, #32; third exception). See the tag-check comment in release.sh. -->

> **Both the app and the DMG are notarized.** Stapling only the app leaves a warning when the DMG is
> opened; stapling only the DMG weakens verification once the app is copied out of it.

Other Keychain profiles or signing identities can be passed by environment variable:

```bash
DDAKA_NOTARY_PROFILE="another-profile" \
DDAKA_SIGN_IDENTITY="Developer ID Application: ..." \
bash release.sh
```

Apple's guide: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

> **This app cannot ship on the Mac App Store.** The App Store requires sandboxing, and the key
> interception (`CGEventTap`) and Input Monitoring permission this app depends on do not work inside
> the sandbox. Direct Developer ID distribution is the only route.

## Project layout

| File | Role |
|---|---|
| `README.md` | Overview, install and usage |
| `README.ja.md` · `README.zh-Hans.md` · `README.zh-Hant.md` | Japanese, Simplified Chinese and Traditional Chinese versions of `README.md` (2026-11-18). Update them whenever `README.md` changes |
| `docs/BUILDING.md` | This document — build, release and layout (moved out of the README on 2026-11-18, #23) |
| `Sources/ddaka/main.swift` | App logic — keyboard blocking, windows, timers, cleaning-screen layout |
| `Sources/ddaka/Themes.swift` | Cleaning-screen themes — the table of 10 scenes (where the text and button go, text colour) and loading of art and fonts (v1.3) |
| `Package.swift` | SwiftPM manifest |
| `Info.plist` | Bundle information |
| `build.sh` | Universal build + `.app` packaging + code signing |
| `release.sh` | Notarization + DMG + DMG notarization + stapling |
| `assets/icon/` | App icon — the source illustration (the same dog and cat as the themes) and outputs (`AppIcon.icns` is what the build uses). Per-file notes and how to regenerate: [`assets/icon/README.md`](../assets/icon/README.md#english) |
| `assets/icon/make-icon.sh` | Crops the source illustration and regenerates the icon up to `AppIcon.icns` (`assets/icon/make-icon.sh <output dir>`; never overwrites the committed files) |
| `assets/themes/` | The 10 cleaning-screen illustrations (2560×1440 JPEG). 🔒 Names and count must match the table in `Themes.swift` — `build.sh` checks it |
| `assets/fonts/` | The four cleaning-screen fonts (Korean/English Gowun Dodum · Japanese Klee One · Simplified Chinese Ddaka Kai SC = an LXGW WenKai subset · Traditional Chinese LXGW WenKai TC) — subsets with only the characters the app uses, plus each SIL OFL 1.1 text. Sources, SHA-256 and how to rebuild: [`assets/fonts/README.md`](../assets/fonts/README.md#english) (2026-11-18) |
| `assets/fonts/make-subsets.sh` · `check-overlay-glyphs.swift` | Builds the Japanese/Chinese subsets · checks that every character of the cleaning-screen strings is in its subset (`build.sh` runs it and stops if one is missing). Neither ships in the app |
| `assets/screenshot.jpg` | The screenshot in this README |
| `assets/readme/themes/` | Preview of the 10 illustrations for this README (480 px thumbnails scaled down from `assets/themes/`; not shipped in the app) |
| `assets/dmg-settings.py` | Installer window layout (background, icon positions, window size) |
| `assets/dmg-background.swift` | Script that draws the installer background (`swift ... <output dir>`) |
| `assets/dmg-background.tiff` | The background it produces (1x + 2x, combined with `tiffutil -cathidpicheck`) |

> 🔒 **The three installer-window files move together.** The background's `W x H` must match
> `window_rect` in `dmg-settings.py` (otherwise the bottom is cut off in the Finder window), and the
> icon coordinates must match the arrow in the background (otherwise the arrow points nowhere).
> If you redraw the background, regenerate the `.tiff` too or nothing changes.

> `release-records/<version>/` accumulates the source record (`source.txt`), dSYM, notarization logs and
> checksum for each release. Re-running the same version moves the previous ones to
> `release-records/<version>.prev-<timestamp>/`, where they stay. It is not committed (local keeping only).
