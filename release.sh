#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ddak-a"
APP_BUNDLE="${APP_NAME}.app"
BINARY_PATH="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
# 🚨 2026-09-22 (v1.1): 볼륨 이름에 버전을 넣는다. 같은 이름의 볼륨이 이미 마운트돼 있으면
# macOS 는 뒤에 번호를 붙여("닦아 ddak-a 1") 따로 띄우는데, 그러면 사용자가 옛 창에서 드래그하고도
# 새 버전을 설치했다고 믿게 된다. 이름이 다르면 두 창이 눈으로 구분된다.
VOLUME_NAME="닦아 ddak-a ${VERSION}"
DIST_DIR="dist"
# 🚨 2026-09-22 (v1.1): 공증 로그와 dSYM 은 .build/ 밖에 둔다.
# .build/ 는 `swift package clean` 한 번에 통째로 날아간다. 크래시 리포트에서 함수 이름을 보려면
# 그때 배포한 바이너리와 짝인 dSYM 이 남아 있어야 하고, 공증 로그는 승인돼도 경고가 실려 있어서
# 나중에 공증이 막힐 때 "그때는 뭐라고 했었나"를 대볼 유일한 근거다.
RELEASE_RECORDS="release-records/${VERSION}"
APP_NOTARY_ARCHIVE=".build/${APP_NAME}-${VERSION}-app-notarization.zip"
FINAL_DMG="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
# 2026-09-22 (F-1): 검증을 다 통과하기 전까지 DMG 가 머무는 자리. dist/ 밖이라 오인 배포를 막는다.
WORK_DMG=".build/${APP_NAME}-${VERSION}.dmg"
# 2026-09-22: 설치 창(배경·아이콘 위치·창 크기)을 만드는 도구. 프로젝트 전용 가상환경에 둔다.
# 시스템 파이썬을 건드리지 않으려는 것이고, .tools 는 저장소에 올리지 않는다.
DMGBUILD=".tools/venv/bin/dmgbuild"
DMGBUILD_PY=".tools/venv/bin/python"
# 🔒 2026-09-22: 1.6.7 이상이어야 한다. macOS 26.2 회귀로 .DS_Store 에 pBBk 블롭이 들어 있으면
# DMG 배경이 표시되지 않는데(FB21405103), dmgbuild 1.6.7 이 그 블롭을 빼면서 해결됐다.
# 그 아래 버전으로 만들면 배경 없는 맨 창이 조용히 나간다 — 빌드는 성공하므로 아무도 못 막는다.
# ⚠️ 검색 요약은 "Bookmark 로 바꿔서 고쳤다"고 정반대를 말한다. 근거는 커밋 diff 다.
DMGBUILD_MIN="1.6.7"
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

# 🚨 2026-09-23 (#6): 커밋하지 않은 변경이 섞인 채로는 배포본을 만들지 않는다.
# 빌드 번호(CFBundleVersion)는 build.sh 가 커밋 수로 붙이는데, 커밋하지 않은 변경은 그 수를
# 바꾸지 않는다 — 소스가 달라도 같은 번호로 나가서, 나중에 "이 빌드가 어느 소스였나"를 되짚을 수 없다.
# 추적하지 않는 새 파일도 막는다. Sources/ 에 새 .swift 가 있으면 커밋하지 않았어도 컴파일된다.
# .gitignore 에 걸린 것(.build/·dist/·release-records/·.tools/ 등)은 소스가 아니라서 보지 않는다.
# 🔒 다른 사전 검사·네트워크·빌드보다 먼저 한다 — 여기서 걸리면 아무것도 건드리지 않고 끝난다.
echo "📋 소스 상태 확인 중..."
if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]; then
    echo "❌ Git 저장소 안에서 실행한 게 아니야 — 어떤 소스로 만든 빌드인지 기록할 수 없어."
    echo "   git clone 한 저장소 폴더에서 실행해줘."
    exit 1
fi
if ! SOURCE_COMMIT="$(git rev-parse --verify --quiet 'HEAD^{commit}')"; then
    echo "❌ 커밋이 하나도 없어 — 어떤 소스로 만든 빌드인지 기록할 수 없어."
    exit 1
fi
SOURCE_COMMIT_SHORT="$(git rev-parse --short "$SOURCE_COMMIT")"
# --untracked-files=all 을 명시한다. 사용자 설정(status.showUntrackedFiles=no)이 새 파일을 숨기면
# 이 가드가 조용히 무력해진다.
if ! SOURCE_STATUS="$(git status --porcelain --untracked-files=all)"; then
    echo "❌ git status 를 읽지 못했어 — 깨끗한지 확인하지 못한 채로는 진행하지 않아."
    exit 1
fi
# dirty 빌드의 diff 해시. 가드에서 한 번, 빌드 뒤에 한 번 계산해 대조하므로 같은 명령을 한 곳에 둔다.
# --binary 가 없으면 바이너리(예: 번들에 들어가는 AppIcon.icns)는 "Binary files differ" 한 줄로만
# 나와서 내용이 달라도 해시가 같아진다. --no-color·--no-ext-diff 는 사용자 Git 설정이 출력(=해시)을
# 바꾸지 못하게 한다. 추적하지 않는 새 파일의 내용은 git diff 에 들어가지 않는다(목록에 이름만 남는다).
source_diff_sha() {
    git diff --no-color --no-ext-diff --binary HEAD | shasum -a 256 | awk '{print $1}'
}
SOURCE_DIRTY="no"
SOURCE_DIFF_SHA=""
if [ -z "$SOURCE_STATUS" ]; then
    echo "   커밋 $SOURCE_COMMIT_SHORT · 작업 폴더 깨끗함 ✓"
elif [ "${DDAKA_ALLOW_DIRTY:-}" = "1" ]; then
    SOURCE_DIRTY="yes"
    SOURCE_DIFF_SHA="$(source_diff_sha)"
    echo "⚠️ ──────────────────────────────────────────────────────────────"
    echo "⚠️  DDAKA_ALLOW_DIRTY=1 — 커밋하지 않은 변경을 섞은 채로 만든다."
    echo "⚠️  이 빌드는 커밋 $SOURCE_COMMIT_SHORT 그대로가 아니다. 빌드 번호가 같아도 소스가 다르다."
    echo "⚠️  source.txt 에 dirty 로 남긴다 (변경 목록 + diff 해시)."
    echo "⚠️ ──────────────────────────────────────────────────────────────"
    printf '%s\n' "$SOURCE_STATUS" | sed 's/^/     /'
else
    echo "❌ 커밋하지 않은 변경이 있어. 이대로 만들면 다른 소스가 같은 빌드 번호로 나간다."
    printf '%s\n' "$SOURCE_STATUS" | sed 's/^/     /'
    echo "   커밋하거나 치워 둔 뒤(git stash -u) 다시 실행해줘."
    echo "   급할 때만: DDAKA_ALLOW_DIRTY=1 bash release.sh (크게 경고하고 기록에 dirty 로 남긴다)"
    exit 1
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
    local result_plist="${RELEASE_RECORDS}/${label}-notary-result.plist"
    local log_json="${RELEASE_RECORDS}/${label}-notary-log.json"
    mkdir -p "$RELEASE_RECORDS"

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
        echo "   제출 ID: $submission_id"
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

DMGBUILD_VERSION="$("$DMGBUILD_PY" -c 'import dmgbuild; print(dmgbuild.__version__)' 2>/dev/null || true)"
if [ -z "$DMGBUILD_VERSION" ]; then
    echo "❌ dmgbuild 버전을 읽지 못했어 ($DMGBUILD_PY)."
    echo "   가상환경이 깨졌을 수 있어. 지우고 다시 만들어줘:"
    echo "   rm -rf .tools/venv && python3 -m venv .tools/venv && .tools/venv/bin/python -m pip install dmgbuild"
    exit 1
fi
if [ "$(printf '%s\n%s\n' "$DMGBUILD_MIN" "$DMGBUILD_VERSION" | sort -V | head -1)" != "$DMGBUILD_MIN" ]; then
    echo "❌ dmgbuild 가 너무 낮아: $DMGBUILD_VERSION (필요: $DMGBUILD_MIN 이상)"
    echo "   이 아래 버전으로 만들면 설치 창 배경이 조용히 빠진 채 배포된다."
    echo "   .tools/venv/bin/python -m pip install --upgrade dmgbuild"
    exit 1
fi
echo "   dmgbuild $DMGBUILD_VERSION (하한 $DMGBUILD_MIN) ✓"

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

# 🚨 2026-09-23 (#6): 어떤 소스로 만든 빌드인지 release-records/<버전>/source.txt 에 남긴다.
# 빌드 직후, 공증 전에 쓴다 — 뒤에서 실패해도 "그 빌드가 어느 커밋이었나"는 남아야 한다.
# 쓰기 전에 셋을 대조한다. 하나라도 어긋나면 기록이 거짓이 되므로 중단한다.
#   ① 빌드하는 동안 HEAD 가 그대로인가 — 다른 창에서 커밋·체크아웃하면 기록할 커밋이 달라진다
#   ② 빌드하는 동안 작업 폴더가 그대로인가 — 맨 앞 가드를 통과한 뒤에 고치면 "깨끗함"이 거짓이 된다
#      (DDAKA_ALLOW_DIRTY 빌드는 이미 고친 파일을 더 고쳐도 목록이 같으므로 diff 해시까지 대조한다)
#   ③ 번들의 빌드 번호(CFBundleVersion)가 커밋 수와 같은가 — build.sh 는 Git 을 못 읽으면 경고만
#      하고 Info.plist 값을 그대로 쓰는데, 배포 경로에서는 그걸 통과시키지 않는다
echo "🧾 빌드한 소스 기록 중..."
if [ "$(git rev-parse HEAD)" != "$SOURCE_COMMIT" ]; then
    echo "❌ 빌드하는 동안 HEAD 가 바뀌었어 ($SOURCE_COMMIT_SHORT → $(git rev-parse --short HEAD))."
    echo "   어느 커밋으로 빌드됐는지 단정할 수 없어. 다시 실행해줘."
    exit 1
fi
SOURCE_STATUS_NOW="$(git status --porcelain --untracked-files=all)"
SOURCE_DIFF_SHA_NOW=""
if [ "$SOURCE_DIRTY" = "yes" ]; then
    SOURCE_DIFF_SHA_NOW="$(source_diff_sha)"
fi
if [ "$SOURCE_STATUS_NOW" != "$SOURCE_STATUS" ] || [ "$SOURCE_DIFF_SHA_NOW" != "$SOURCE_DIFF_SHA" ]; then
    echo "❌ 빌드하는 동안 작업 폴더가 바뀌었어 — 무엇이 빌드에 들어갔는지 단정할 수 없어."
    if [ "$SOURCE_STATUS_NOW" = "$SOURCE_STATUS" ]; then
        echo "   (바뀐 파일 목록은 그대로지만, 이미 고쳐 둔 파일의 내용이 빌드 도중에 또 바뀌었어)"
    fi
    echo "   지금 상태:"
    printf '%s\n' "$SOURCE_STATUS_NOW" | sed 's/^/     /'
    exit 1
fi
SOURCE_COMMIT_COUNT="$(git rev-list --count HEAD)"
if ! BUNDLE_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"; then
    echo "❌ 번들에서 빌드 번호(CFBundleVersion)를 읽지 못했어: $APP_BUNDLE/Contents/Info.plist"
    exit 1
fi
if [ "$BUNDLE_BUILD_NUMBER" != "$SOURCE_COMMIT_COUNT" ]; then
    echo "❌ 번들의 빌드 번호가 커밋 수와 달라 (번들: $BUNDLE_BUILD_NUMBER · 커밋 수: $SOURCE_COMMIT_COUNT)."
    echo "   build.sh 가 빌드 번호를 붙이지 못했거나 다른 빌드가 섞였어. 위 build.sh 출력을 확인해줘."
    exit 1
fi
# 값은 먼저 변수에 받는다 — echo 인자 안의 $(…) 는 실패해도 set -e 에 걸리지 않고 빈 값으로 새어 나간다.
SOURCE_BRANCH="$(git symbolic-ref --short -q HEAD || echo '(detached)')"
SOURCE_DESCRIBE="$(git describe --tags --always)"
SOURCE_RECORDED_AT="$(date '+%Y-%m-%dT%H:%M:%S%z' | sed -E 's/([+-][0-9][0-9])([0-9][0-9])$/\1:\2/')"
SOURCE_RECORD="$RELEASE_RECORDS/source.txt"
mkdir -p "$RELEASE_RECORDS"
{
    echo "# 닦아(ddak-a) 배포본의 소스 기록 — release.sh 가 빌드 직후에 남긴다."
    echo "# dirty: no 면 'git checkout <commit>' 으로 이 빌드의 소스를 그대로 다시 볼 수 있다."
    echo "version: $VERSION"
    echo "commit: $SOURCE_COMMIT"
    echo "commit_short: $SOURCE_COMMIT_SHORT"
    echo "branch: $SOURCE_BRANCH"
    echo "commit_count: $SOURCE_COMMIT_COUNT (= 번들의 CFBundleVersion)"
    echo "describe: $SOURCE_DESCRIBE"
    echo "dirty: $SOURCE_DIRTY"
    if [ "$SOURCE_DIRTY" = "yes" ]; then
        echo "dirty_diff_sha256: $SOURCE_DIFF_SHA"
        echo "#   다시 계산: git diff --no-color --no-ext-diff --binary HEAD | shasum -a 256"
        echo "#   추적하지 않는 새 파일은 이 diff 에 들어가지 않는다 — 아래 목록에 이름으로만 남는다."
        echo "dirty_status:"
        printf '%s\n' "$SOURCE_STATUS" | sed 's/^/    /'
    fi
    echo "recorded_at: $SOURCE_RECORDED_AT"
} > "$SOURCE_RECORD"
echo "   $SOURCE_RECORD (커밋 $SOURCE_COMMIT_SHORT · 빌드 번호 $SOURCE_COMMIT_COUNT · dirty: $SOURCE_DIRTY)"

echo "🔍 서명과 아키텍처 확인 중..."
# 🚨 2026-09-22: lipo 의 -verify_arch 는 usage 표기(`-verify_arch <arch> ...`)와 달리
# 아키텍처를 하나만 받는다. 두 개를 주면 두 번째를 입력 파일로 해석해
# "requires exactly one input file" 로 실패한다(실측). 그래서 한 번에 하나씩 확인한다.
lipo "$BINARY_PATH" -verify_arch arm64
lipo "$BINARY_PATH" -verify_arch x86_64
# 🚨 2026-09-22 (v1.1): --deep 을 붙인다. Gatekeeper 는 번들 안쪽까지 훑어보는데
# --deep 없는 --verify 는 겉껍데기만 본다 — 안쪽이 깨져 있어도 여기서는 통과해 버린다.
# 🔒 --deep 은 "검증"에만 쓴다. 서명(codesign --sign)에 --deep 을 붙이면 안 된다
#    — 중첩된 코드의 서명을 잘못 덮어쓰는 방식이라 애플이 권장하지 않는다.
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# 🚨 2026-09-22 (v1.1): "서명이 됐다"가 아니라 "제대로 됐다"를 단언한다.
# 셋 다 지금까지는 사람이 눈으로 확인하던 것인데, 안 보고 넘어가면 공증 단계에 가서야
# (또는 인증서 만료 뒤 사용자 손에서야) 드러난다.
echo "🔎 서명 속성 단언 중..."
SIGN_INFO="$(codesign --display --verbose=4 "$APP_BUNDLE" 2>&1)"

# (1) Hardened Runtime — 없으면 공증이 거부된다
if ! printf '%s' "$SIGN_INFO" | grep -q 'flags=.*runtime'; then
    echo "❌ Hardened Runtime 이 켜져 있지 않아 (codesign --options runtime 누락)."
    printf '%s\n' "$SIGN_INFO" | grep '^CodeDirectory' || true
    exit 1
fi

# (2) 신뢰할 수 있는 타임스탬프 — 없으면 인증서가 만료되는 순간 서명이 통째로 무효가 된다.
#     서명 시점에 애플 타임스탬프 서버에 못 닿으면 조용히 빠질 수 있다.
if ! printf '%s' "$SIGN_INFO" | grep -q '^Timestamp='; then
    echo "❌ 신뢰 타임스탬프가 없어 (--timestamp 누락, 또는 서명 때 네트워크 실패)."
    exit 1
fi

# (3) get-task-allow — 디버거를 붙일 수 있게 하는 디버그용 권한. 섞이면 공증이 거부된다.
# 🚨 2026-09-22 (PR #1 리뷰 F-1): 종전에는 뒤에 `|| true` 를 붙여 덤프 실패까지 삼켰다.
# 그러면 명령이 깨져서 오류 문구만 돌아와도 grep 이 아무것도 못 찾아 "없음 ✓" 으로 통과한다
# — 금속탐지기가 꺼져 있는데 "삐 소리가 안 났으니 통과"라고 하는 꼴이다.
# 같은 절의 (1)·(2)는 명령이 실패하면 set -e 로 멈추는데 이 하나만 헐거웠다.
# 🔒 "깨끗하다"와 "못 봤다"를 가른다 — 확인하지 못했으면 통과시키지 않는다.
ENTITLEMENTS_EXIT=0
APP_ENTITLEMENTS="$(codesign --display --entitlements - --xml "$APP_BUNDLE" 2>&1)" || ENTITLEMENTS_EXIT=$?
if [ "$ENTITLEMENTS_EXIT" -ne 0 ]; then
    echo "❌ 권한(entitlements) 목록을 읽지 못했어 (codesign 종료코드 $ENTITLEMENTS_EXIT)."
    echo "   읽지 못한 것은 '섞여 있지 않다'의 근거가 되지 못한다."
    printf '%s\n' "$APP_ENTITLEMENTS" | sed 's/^/   /'
    exit 1
fi
if printf '%s' "$APP_ENTITLEMENTS" | grep -q 'get-task-allow'; then
    echo "❌ get-task-allow 가 섞여 있어. 디버그 빌드가 배포 경로로 들어왔다."
    exit 1
fi
echo "   Hardened Runtime ✓ · 신뢰 타임스탬프 ✓ · get-task-allow 없음 ✓"

# 🚨 2026-09-22 (v1.1): 디버그 심볼(dSYM)을 .build/ 밖으로 보관한다.
# 없으면 사용자가 보내온 크래시 리포트에 함수 이름이 안 나오고 주소만 남는다.
# 🔒 경로를 손으로 적지 않는다 — 낡은 .build/apple/Products/Release 아래에 8월자 dSYM 이
#    아직 남아 있어서(2026-09-22 실측) 그쪽을 집으면 엉뚱한 심볼을 보관하게 된다.
echo "🧷 디버그 심볼(dSYM) 보관 중..."
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
DSYM_SRC="$BIN_DIR/ddaka.dSYM"
if [ ! -d "$DSYM_SRC" ]; then
    echo "❌ dSYM 을 찾지 못했어: $DSYM_SRC"
    exit 1
fi
# 이름만 같고 내용이 다른 dSYM 은 크래시 리포트를 엉뚱하게 풀어 주므로 없는 것만 못하다.
# 배포하는 바이너리와 같은 빌드인지 UUID 로 대조한다(아키텍처 2개 모두).
APP_UUIDS="$(dwarfdump --uuid "$BINARY_PATH" | awk '{print $2}' | sort)"
DSYM_UUIDS="$(dwarfdump --uuid "$DSYM_SRC" | awk '{print $2}' | sort)"
if [ "$APP_UUIDS" != "$DSYM_UUIDS" ]; then
    echo "❌ dSYM 이 배포 바이너리와 다른 빌드야 (UUID 불일치)."
    echo "   앱:"; printf '%s\n' "$APP_UUIDS" | sed 's/^/     /'
    echo "   dSYM:"; printf '%s\n' "$DSYM_UUIDS" | sed 's/^/     /'
    exit 1
fi
mkdir -p "$RELEASE_RECORDS"
rm -rf "$RELEASE_RECORDS/ddaka.dSYM"
cp -R "$DSYM_SRC" "$RELEASE_RECORDS/ddaka.dSYM"
echo "   보관: $RELEASE_RECORDS/ddaka.dSYM (UUID 일치 확인)"

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
# 경로로 옮겨 실행한다. 그 임시 경로에서 실행되면 손쉬운 사용·입력 모니터링 권한이 붙지
# 않는다 — 켜도 다음 실행 때 다시 꺼져 있다(실측).
# ⚠️ 2026-09-22 정정: 여기 원래 "권한은 경로를 함께 기억하므로"라고 적혀 있었다. 그건 기전
#    단정이고 1차 근거가 없다. 권한 DB가 무엇으로 앱을 식별하는지는 확인하지 못했다.
#    관측된 사실까지만 적는다. (같은 문장이 README 에도 있었고 함께 고쳤다.)
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

# 🚨 2026-09-22 (v1.1): 배포물 해시를 남긴다. 받은 파일이 올린 그 파일인지 사용자가 직접
# 대조할 수 있고(`shasum -c`), 나중에 "그때 올린 게 이거였나"를 우리도 되짚을 수 있다.
# 파일 안에는 경로 없이 파일명만 들어가야 -c 로 검사가 된다 → 서브셸에서 dist 로 들어간다.
echo "🔢 배포물 SHA-256 기록 중..."
SHA_FILE="${FINAL_DMG}.sha256"
( cd "$DIST_DIR" && shasum -a 256 "$(basename "$FINAL_DMG")" > "$(basename "$SHA_FILE")" )
cp "$SHA_FILE" "$RELEASE_RECORDS/"

echo ""
echo "✅ 외부 배포 준비 완료: $FINAL_DMG"
echo "   버전: $VERSION"
echo "   앱과 DMG 모두 공증 + 티켓 부착 완료."
echo "   체크섬: $SHA_FILE"
echo "$(cat "$SHA_FILE")" | sed 's/^/     /'
echo "   기록 보관: $RELEASE_RECORDS/ (소스 기록 · dSYM · 공증 로그 · 체크섬)"
echo "   소스 기록: $SOURCE_RECORD (커밋 $SOURCE_COMMIT_SHORT · 빌드 번호 $SOURCE_COMMIT_COUNT)"
if [ "$SOURCE_DIRTY" = "yes" ]; then
    echo "   ⚠️ 커밋하지 않은 변경이 섞인 빌드다 (DDAKA_ALLOW_DIRTY=1) — 이 커밋만으로는 재현되지 않는다."
fi
echo ""
# 🔒 2026-09-22 (PR #1 리뷰 F-4): 체크섬은 올려야 값어치가 생긴다.
# dist/ 도 release-records/ 도 저장소에 안 올라가므로, 여기서 말해 주지 않으면
# "받은 파일이 올린 그 파일인지 사용자가 대조한다"는 원래 목적을 못 한다.
echo "📌 다음: 릴리스에 아래 둘을 함께 올린다"
echo "     $FINAL_DMG"
echo "     $SHA_FILE   ← 이걸 같이 올려야 사용자가 shasum -c 로 대조할 수 있다"
