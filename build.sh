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

BIN_PATH=".build/apple/Products/Release/ddaka"
if [ ! -f "$BIN_PATH" ]; then
    BIN_PATH=".build/release/ddaka"
fi

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/ddak-a"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/ddak-a"

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
file "$APP_BUNDLE/Contents/MacOS/ddak-a"
