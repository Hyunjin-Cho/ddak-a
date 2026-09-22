#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ddak-a"
APP_BUNDLE="${APP_NAME}.app"
BINARY_PATH="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
VOLUME_NAME="닦아 ddak-a"
DIST_DIR="dist"
APP_NOTARY_ARCHIVE=".build/${APP_NAME}-${VERSION}-app-notarization.zip"
FINAL_DMG="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
# 2026-09-22 (F-1): 검증을 다 통과하기 전까지 DMG 가 머무는 자리. dist/ 밖이라 오인 배포를 막는다.
WORK_DMG=".build/${APP_NAME}-${VERSION}.dmg"
# 2026-09-22: 설치 창(배경·아이콘 위치·창 크기)을 만드는 도구. 프로젝트 전용 가상환경에 둔다.
# 시스템 파이썬을 건드리지 않으려는 것이고, .tools 는 저장소에 올리지 않는다.
DMGBUILD=".tools/venv/bin/dmgbuild"
DMG_SETTINGS="assets/dmg-settings.py"

# notarytool 인증 정보는 저장소가 아니라 macOS 키체인에 보관한다.
# 다른 이름을 썼다면 DDAKA_NOTARY_PROFILE 환경변수로 바꿀 수 있다.
NOTARY_PROFILE="${DDAKA_NOTARY_PROFILE:-ddaka-notary}"
SIGN_IDENTITY="${DDAKA_SIGN_IDENTITY:-Developer ID Application: Hyunjin Cho (6RH6FXY82P)}"

if [ "${1:-}" = "--help" ]; then
    echo "사용법: bash release.sh"
    echo "필요한 키체인 프로필: $NOTARY_PROFILE"
    echo "결과 파일: $FINAL_DMG"
    exit 0
fi

if [ "$#" -ne 0 ]; then
    echo "❌ 알 수 없는 옵션: $1"
    echo "사용법: bash release.sh"
    exit 2
fi

# 🚨 2026-09-22: 공증은 "제출 → 대기 → 결과 판정 → 로그 저장"이 앱과 DMG 두 번 반복된다.
# 같은 절차를 두 벌 적으면 한쪽만 고치는 사고가 나므로 함수 하나로 묶는다.
#
# 🚨 2026-09-22 수정: 이전 버전은 제출 실패 시 plutil이 먼저 죽어버려(set -e)
# 아래 "공증이 승인되지 않았어" 안내를 사용자가 보지 못하고 끝났다.
# plutil 호출마다 실패를 흡수해서, 판정과 안내가 반드시 실행되게 한다.
notarize_and_staple() {
    local target_path="$1"   # 공증 티켓을 붙일 실물 (.app 또는 .dmg)
    local upload_path="$2"   # Apple에 올릴 파일 (.zip 또는 .dmg)
    local label="$3"
    local result_plist=".build/${APP_NAME}-${VERSION}-${label}-notary-result.plist"
    local log_json=".build/${APP_NAME}-${VERSION}-${label}-notary-log.json"

    echo "☁️ Apple 공증 서비스에 제출 중 (${label})..."
    echo "   키체인 프로필: $NOTARY_PROFILE"
    rm -f "$result_plist" "$log_json"

    local submit_exit=0
    xcrun notarytool submit "$upload_path" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait \
        --output-format plist > "$result_plist" || submit_exit=$?

    if [ ! -s "$result_plist" ]; then
        echo "❌ 공증 서비스가 결과 파일을 돌려주지 않았어 (${label})."
        echo "   네트워크와 키체인 프로필($NOTARY_PROFILE)을 확인해줘."
        return 1
    fi

    /usr/bin/plutil -p "$result_plist" || true

    local submission_id=""
    local submission_status=""
    submission_id="$(/usr/bin/plutil -extract id raw -o - "$result_plist" 2>/dev/null || true)"
    submission_status="$(/usr/bin/plutil -extract status raw -o - "$result_plist" 2>/dev/null || true)"

    if [ -n "$submission_id" ]; then
        echo "🧾 공증 로그 내려받는 중..."
        xcrun notarytool log "$submission_id" "$log_json" \
            --keychain-profile "$NOTARY_PROFILE" || true
        echo "   로그: $log_json"
    else
        echo "   ⚠️ 제출 ID를 읽지 못해 로그를 내려받지 못했어. 위 결과를 직접 확인해줘."
    fi

    if [ "$submit_exit" -ne 0 ] || [ "$submission_status" != "Accepted" ]; then
        echo "❌ 공증이 승인되지 않았어 (${label} · 상태: ${submission_status:-알 수 없음})."
        echo "   위 결과와 로그를 확인해줘."
        return 1
    fi

    echo "🎫 공증 티켓 붙이는 중 (${label})..."
    xcrun stapler staple "$target_path"
    xcrun stapler validate "$target_path"
}

if ! xcrun --find notarytool >/dev/null 2>&1; then
    echo "❌ notarytool을 찾지 못했어. Xcode 14 이상이 선택돼 있는지 확인해줘."
    exit 1
fi

if ! xcrun --find stapler >/dev/null 2>&1; then
    echo "❌ stapler를 찾지 못했어. Xcode 설치 상태를 확인해줘."
    exit 1
fi

if ! IDENTITIES="$(security find-identity -v -p codesigning)"; then
    echo "❌ 코드 서명 인증서 목록을 읽지 못했어."
    exit 1
fi

if [[ "$IDENTITIES" != *"$SIGN_IDENTITY"* ]]; then
    echo "❌ 외부 배포에 필요한 Developer ID Application 인증서를 찾지 못했어."
    echo "   찾는 신원: $SIGN_IDENTITY"
    echo "   ad-hoc 서명으로는 공증하지 않아."
    exit 1
fi

# 🚨 2026-09-22: 키체인 프로필이 없으면 공증 제출 단계에 가서야 실패한다.
# 유니버설 빌드를 몇 분 돌린 뒤에 깨지는 건 낭비라, 시작 전에 미리 확인한다.
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "❌ 공증용 키체인 프로필 '$NOTARY_PROFILE' 을 쓸 수 없어."
    echo "   최초 한 번 아래를 실행해 앱 전용 암호를 저장해줘:"
    echo ""
    echo "   xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\"
    echo "     --apple-id \"<Apple ID>\" --team-id \"6RH6FXY82P\""
    echo ""
    echo "   앱 전용 암호 발급: https://account.apple.com → 로그인 및 보안 → 앱 전용 암호"
    exit 1
fi

# 🚨 2026-09-22: 설치 창을 만드는 도구가 없으면 DMG 단계에서야 깨진다 — 빌드 전에 확인한다.
if [ ! -x "$DMGBUILD" ]; then
    echo "❌ dmgbuild 를 찾지 못했어: $DMGBUILD"
    echo "   프로젝트 전용 가상환경에 한 번만 설치하면 된다:"
    echo ""
    echo "   python3 -m venv .tools/venv"
    echo "   .tools/venv/bin/python -m pip install dmgbuild"
    exit 1
fi

if [ ! -f "$DMG_SETTINGS" ]; then
    echo "❌ DMG 설치 창 설정을 찾지 못했어: $DMG_SETTINGS"
    exit 1
fi

# 🚨 2026-09-22 (F-2): 아이콘이 없으면 build.sh 는 경고만 하고 기본 아이콘으로 빌드한다.
# 공증도 아이콘 유무를 보지 않으므로, 아무도 막지 않으면 기본 아이콘을 단 앱이 배포된다.
# 배포 경로에서는 경고가 아니라 중단이 맞다 — 긴 빌드 전에 여기서 걸러낸다.
if [ ! -f "assets/icon/AppIcon.icns" ]; then
    echo "❌ 앱 아이콘을 찾지 못했어: assets/icon/AppIcon.icns"
    echo "   Info.plist 의 CFBundleIconFile 이 AppIcon 을 가리키는데 파일이 없어."
    echo "   기본 아이콘으로 배포되는 것을 막기 위해 여기서 멈춘다."
    exit 1
fi

echo "🚀 외부 배포용 앱 빌드 중..."
DDAKA_SIGN_IDENTITY="$SIGN_IDENTITY" bash build.sh

echo "🔍 서명과 아키텍처 확인 중..."
# 🚨 2026-09-22: lipo 의 -verify_arch 는 usage 표기(`-verify_arch <arch> ...`)와 달리
# 아키텍처를 하나만 받는다. 두 개를 주면 두 번째를 입력 파일로 해석해
# "requires exactly one input file" 로 실패한다(실측). 그래서 한 번에 하나씩 확인한다.
lipo "$BINARY_PATH" -verify_arch arm64
lipo "$BINARY_PATH" -verify_arch x86_64
codesign --verify --strict --verbose=2 "$APP_BUNDLE"

echo "📦 앱 공증 제출용 ZIP 만드는 중..."
mkdir -p .build
rm -f "$APP_NOTARY_ARCHIVE"
ditto -c -k --keepParent "$APP_BUNDLE" "$APP_NOTARY_ARCHIVE"

# 1단계 — 앱 자체를 공증하고 티켓을 붙인다.
# DMG에서 꺼낸 앱이 단독으로도 오프라인에서 통과하려면 앱에 티켓이 붙어 있어야 한다.
notarize_and_staple "$APP_BUNDLE" "$APP_NOTARY_ARCHIVE" "app"

echo "🛡️ 앱 Gatekeeper 확인 중..."
spctl --assess --type execute --verbose=2 "$APP_BUNDLE"

# 2단계 — 티켓이 붙은 앱으로 DMG를 만든다.
#
# 🚨 2026-09-22: ZIP이 아니라 DMG로 배포하는 이유 = App Translocation.
# quarantine 딱지가 붙은 앱을 응용 프로그램 폴더 밖에서 실행하면 macOS가 랜덤 읽기전용
# 경로로 옮겨 실행한다. 그러면 실행할 때마다 경로가 달라지는데, 손쉬운 사용·입력 모니터링
# 권한은 경로를 함께 기억하므로 "권한을 켜도 계속 안 켜진 것처럼" 동작한다.
# 사용자가 Finder로 응용 프로그램 폴더에 직접 옮기면 그 딱지가 풀린다 →
# DMG 안에 /Applications 바로가기를 같이 넣어 그 드래그를 유도한다.
echo "🗂  DMG 만드는 중..."
# 🚨 2026-09-22: 설치 창 모양(배경 그림·아이콘 위치·창 크기)은 .DS_Store 에 저장되는데,
# 그걸 만드는 정상 경로인 Finder AppleScript 의 "배경 그림 지정"이 macOS 27 에서 깨져 있다
# — 설정하면 오류 없이 조용히 무시되고, 읽으면 -10000 오류가 난다(실측).
# dmgbuild 는 Finder 를 거치지 않고 .DS_Store 를 직접 만들기 때문에 그 버그의 영향을 받지 않는다.
# 창 구성은 전부 $DMG_SETTINGS 에 있다.
rm -f "$WORK_DMG"
"$DMGBUILD" -s "$DMG_SETTINGS" -D app="$APP_BUNDLE" "$VOLUME_NAME" "$WORK_DMG"

# 3단계 — DMG도 서명·공증한다.
# 앱에만 티켓을 붙이면 DMG 자체는 미검증 상태라, 내려받아 열 때 경고가 뜬다.
echo "🔏 DMG 서명 중..."
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$WORK_DMG"
codesign --verify --strict --verbose=2 "$WORK_DMG"

notarize_and_staple "$WORK_DMG" "$WORK_DMG" "dmg"

echo "🛡️ DMG Gatekeeper 최종 확인 중..."
spctl --assess --type open --context context:primary-signature --verbose=2 "$WORK_DMG"

# 여기까지 왔으면 서명·공증·티켓·Gatekeeper 를 모두 통과했다. 이제서야 배포 폴더로 옮긴다.
echo "📤 배포 폴더로 옮기는 중..."
mkdir -p "$DIST_DIR"
rm -f "$FINAL_DMG"
mv "$WORK_DMG" "$FINAL_DMG"
xcrun stapler validate "$FINAL_DMG"

echo ""
echo "✅ 외부 배포 준비 완료: $FINAL_DMG"
echo "   버전: $VERSION"
echo "   앱과 DMG 모두 공증 + 티켓 부착 완료."
