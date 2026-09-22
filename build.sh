#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔨 유니버설(Intel+Apple Silicon) 빌드 중..."
swift build -c release --arch arm64 --arch x86_64

APP_NAME="ddak-a"
APP_BUNDLE="${APP_NAME}.app"

echo "📦 ${APP_BUNDLE} 번들 만드는 중..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 🚨 2026-09-22: 산출물 경로를 손으로 적지 않고 SwiftPM 에게 직접 묻는다.
# 예전 경로는 .build/apple/Products/Release 였는데 툴체인이 .build/out/Products/Release 로 바꿨다.
# 종전 코드는 "옛 경로에 파일이 있으면 그걸 쓴다"는 식이어서, 거기 남아 있던 8월 14일자
# 낡은 바이너리를 계속 복사하고 있었다(배포 직전 발견 — 고친 소스가 반영되지 않은 채
# 공증될 뻔했다). 경로는 툴체인이 바꾸는 값이므로 박아두면 반드시 어긋난다.
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BIN_PATH="$BIN_DIR/ddaka"
if [ ! -f "$BIN_PATH" ]; then
    echo "❌ 빌드 산출물을 찾지 못했어: $BIN_PATH"
    exit 1
fi
echo "   산출물: $BIN_PATH"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/ddak-a"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/ddak-a"

# 2026-09-22: 앱 아이콘. Info.plist 의 CFBundleIconFile 이 이 파일명을 가리킨다.
# 없어도 빌드는 되지만 기본 아이콘으로 나가므로 배포 전에 반드시 확인한다.
ICON_SRC="assets/icon/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "   ⚠️ $ICON_SRC 를 찾지 못했어 → 기본 아이콘으로 빌드된다"
fi

# 🚨 2026-08-12 변경: ad-hoc 서명(--sign -)은 인증서가 없어서 재빌드마다 서명 해시가 바뀐다.
# macOS의 권한 시스템(TCC)은 그걸 "다른 앱"으로 보기 때문에 손쉬운 사용·입력 모니터링 권한이
# 매번 풀렸다. 정식 인증서로 서명하면 앱 신원이 고정돼 재빌드해도 권한이 유지된다.
# (오너가 이미 보유 중인 Developer ID Application 인증서 사용 — 배포·공증에도 그대로 쓸 수 있음)
SIGN_IDENTITY="${DDAKA_SIGN_IDENTITY:-Developer ID Application: Hyunjin Cho (6RH6FXY82P)}"

echo "🔏 코드사이닝 중..."
if security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY"; then
    echo "   신원: $SIGN_IDENTITY"
    # 🚨 2026-08-12: 공증(notarization)에는 Hardened Runtime(--options runtime)과
    # 신뢰할 수 있는 타임스탬프(--timestamp)가 필수다. 배포 전에 미리 켜서
    # 이 보안 모드가 키보드 차단 기능을 깨뜨리지 않는지 먼저 확인한다.
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
    echo "   ⚠️ 인증서를 못 찾음 → ad-hoc 서명으로 대체 (재빌드마다 권한이 풀릴 수 있음)"
    codesign --force --sign - "$APP_BUNDLE"
fi

echo "✅ 완료: $APP_BUNDLE"
# 🚨 2026-09-22: lipo 의 -verify_arch 는 usage 표기(`-verify_arch <arch> ...`)와 달리
# 아키텍처를 하나만 받는다. 두 개를 주면 두 번째를 입력 파일로 해석해
# "requires exactly one input file" 로 실패한다(실측). 그래서 한 번에 하나씩 확인한다.
lipo "$APP_BUNDLE/Contents/MacOS/ddak-a" -verify_arch arm64
lipo "$APP_BUNDLE/Contents/MacOS/ddak-a" -verify_arch x86_64
file "$APP_BUNDLE/Contents/MacOS/ddak-a"
