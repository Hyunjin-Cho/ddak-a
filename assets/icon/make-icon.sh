#!/bin/bash
# 닦아 앱 아이콘을 원본 그림에서 AppIcon.icns 까지 다시 만든다 — 2026-09-23 (#11) · 2026-11-18 (#21) 원본 교체
#
# 사용법: assets/icon/make-icon.sh <출력폴더>
#
# 🚨 2026-09-23 (#11): 이 과정은 그동안 어디에도 적혀 있지 않아서 저장소만으로는 아이콘을 다시 만들 수 없었다.
#   2026-09-22 에 아이콘을 만들 때 실제로 쓴 명령(당시 작업 기록으로 확인)을 그대로 옮겼고, 2026-09-23 에
#   다시 돌려 커밋된 네 파일(AppIcon.icns · AppIcon-1024.png · AppIcon-256.png · 검증-크기별.png)과
#   바이트 단위로 같게 나오는 것을 확인했다.
# 🚨 2026-11-18 (#21): 원본을 SVG(원본-소프트3D.svg, QuiverAI Arrow)에서 v1.3 테마 그림체의 일러스트
#   (원본-테마.jpg, Seedream 5.5 생성 2048×2048)로 바꿨다. 그래서 ①②단계가 "SVG 여백 자르기 → Quick Look 렌더"에서
#   "정사각으로 잘라 위아래 여백 줄이기"로 바뀌었다. ③~⑥(mask.swift · icns · 256 · 대조)은 그대로다.
#   옛 SVG 는 git 기록에 있다: git show 271d58c:assets/icon/원본-소프트3D.svg
# 🔒 2026-09-23 (#11): 커밋된 파일(이 폴더)은 덮어쓰지 않는다. 결과는 <출력폴더> 에만 쓰고, 끝에 대조만 한다.
#   아이콘을 실제로 바꾸려면 결과(특히 검증-크기별.png)를 눈으로 확인한 뒤 직접 복사한다.
# macOS 에 들어 있는 도구(sips · iconutil)와 swift(Xcode 또는 Command Line Tools)만 쓴다.
set -euo pipefail

ICON_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SRC="$ICON_DIR/원본-테마.jpg"
# 2026-11-18 (#21): 오너가 고른 자르기 — 2048 원본에서 한 변 1720 정사각, 가운데 (1045, 1034).
#   그림 속 내용(강아지·고양이·키·그림자)은 폭 1524 × 높이 1164 로 가로로 길어서, 정사각으로 자르면 좌우가 먼저 준다.
#   1720 이면 좌우 약 7%·4%, 위아래 약 16% 가 남는다(원본은 위아래 약 22%). 시안 비교는 오너 자료 폴더에 있다.
#   sips 의 --cropOffset 은 "위 왼" 순서다. 🔒 0 0 을 주면 무시되고 가운데로 잘린다(2026-11-18 실측) — 여기 값은 0 이 아니다.
SRC_SIZE="2048x2048"
CROP_SIDE=1720
CROP_TOP=174    # 1034 - 1720/2
CROP_LEFT=185   # 1045 - 1720/2

usage() {
    echo "사용법: $0 <출력폴더>"
    echo "  원본-테마.jpg 에서 AppIcon.icns 까지 만들어 <출력폴더> 에 쓴다."
    echo "  이 폴더(assets/icon)의 커밋된 파일은 건드리지 않고, 끝에 대조만 한다."
}

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
    usage >&2
    exit 2
fi
case "$1" in
    -h|--help) usage; exit 0 ;;
esac

for tool in sips iconutil swift; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ '$tool' 을 찾지 못했어 — macOS 기본 도구와 swift(Xcode 또는 Command Line Tools)가 필요하다" >&2
        exit 1
    fi
done
if [ ! -f "$SRC" ]; then
    echo "❌ 원본 그림이 없어: $SRC" >&2
    exit 1
fi

mkdir -p "$1"
OUT="$(cd "$1" && pwd -P)"
# 같은 폴더인지는 경로 문자열이 아니라 실제 폴더(-ef)로 비교한다 — 대소문자·심볼릭 링크로 돌아와도 막힌다
if [ "$OUT" -ef "$ICON_DIR" ]; then
    echo "❌ 출력 폴더가 assets/icon 자신이다 — 커밋된 파일을 덮어쓰게 되므로 멈춘다. 다른 폴더를 줘." >&2
    exit 1
fi
WORK="$OUT/work"            # 중간 산출물 — 문제가 생겼을 때 단계별로 열어 보라고 남긴다
ICONSET="$WORK/AppIcon.iconset"
rm -rf "$ICONSET"           # 지난 실행의 크기별 PNG 가 섞이지 않게
mkdir -p "$ICONSET"

echo "① 원본 크기 확인 — $SRC_SIZE"
# 자르는 위치는 2048 원본 기준 숫자다. 원본이 바뀌어 크기가 다르면 엉뚱한 곳을 자르게 되므로 멈춘다.
SIZE="$(sips -g pixelWidth -g pixelHeight "$SRC" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')"
if [ "$SIZE" != "$SRC_SIZE" ]; then
    echo "❌ 원본 크기가 $SRC_SIZE 가 아니라 $SIZE 다: $SRC" >&2
    echo "   새 원본이라면 이 스크립트의 CROP_* 값을 그 그림에 맞게 고쳐야 한다." >&2
    exit 1
fi

echo "② 정사각 자르기 — 한 변 $CROP_SIDE · 위 $CROP_TOP · 왼 $CROP_LEFT"
CROPPED="$WORK/icon-crop.png"
rm -f "$CROPPED"
sips -s format png -c "$CROP_SIDE" "$CROP_SIDE" --cropOffset "$CROP_TOP" "$CROP_LEFT" "$SRC" --out "$CROPPED" >/dev/null
SIZE="$(sips -g pixelWidth -g pixelHeight "$CROPPED" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')"
if [ "$SIZE" != "${CROP_SIDE}x${CROP_SIDE}" ]; then
    echo "❌ 자른 크기가 ${CROP_SIDE}x${CROP_SIDE} 가 아니라 $SIZE 다: $CROPPED" >&2
    exit 1
fi

echo "③ macOS 규격 입히기 — mask.swift (모서리 곡선 + 1024 안에 824)"
swift "$ICON_DIR/mask.swift" "$CROPPED" "$OUT/AppIcon-1024.png" "$OUT/검증-크기별.png"

echo "④ 크기별 PNG 10장 → AppIcon.icns"
while read -r px name; do
    sips -s format png -z "$px" "$px" "$OUT/AppIcon-1024.png" --out "$ICONSET/$name.png" >/dev/null
done <<'EOF'
16 icon_16x16
32 icon_16x16@2x
32 icon_32x32
64 icon_32x32@2x
128 icon_128x128
256 icon_128x128@2x
256 icon_256x256
512 icon_256x256@2x
512 icon_512x512
1024 icon_512x512@2x
EOF
iconutil -c icns "$ICONSET" -o "$OUT/AppIcon.icns"

echo "⑤ README 머리용 256"
sips -s format png -z 256 256 "$OUT/AppIcon-1024.png" --out "$OUT/AppIcon-256.png" >/dev/null

echo "⑥ 커밋된 파일과 대조 (assets/icon 은 건드리지 않았다)"
DIFFERENT=0
for f in AppIcon.icns AppIcon-1024.png AppIcon-256.png 검증-크기별.png; do
    if [ ! -f "$ICON_DIR/$f" ]; then
        echo "   ?  $f — 대조할 커밋 파일이 없다"
    elif cmp -s "$OUT/$f" "$ICON_DIR/$f"; then
        echo "   =  $f — 같다 (바이트 단위)"
    else
        echo "   ≠  $f — 다르다"
        DIFFERENT=$((DIFFERENT + 1))
    fi
done

echo ""
echo "✅ 완료: $OUT  (macOS $(sw_vers -productVersion) · $(sw_vers -buildVersion))"
if [ "$DIFFERENT" -gt 0 ]; then
    echo "   원본 그림을 바꾸지 않았는데도 다르면 macOS 차이일 가능성이 크다 — JPEG 디코더(sips), 비교 시트의"
    echo "   시스템 폰트, PNG 인코더는 macOS 에 딸려 있어서 버전이 바뀌면 결과가 달라질 수 있다."
    echo "   검증-크기별.png 를 눈으로 확인한 뒤에 바꿀지 정한다."
fi
# 2026-09-23: 복사 명령을 경로째 찍어 주지 않는다 — 저장소 경로의 '!'(ddak-a!)는 대화형 셸에 붙여 넣으면
#   큰따옴표 안에서도 히스토리 확장으로 깨지고, bash 3.2 의 printf %q 는 한글 경로를 망가뜨린다(둘 다 실측).
echo "   아이콘을 이 결과로 바꾸려면 확인한 뒤 네 파일을 직접 assets/icon/ 에 복사한다:"
echo "   AppIcon.icns · AppIcon-1024.png · AppIcon-256.png · 검증-크기별.png"
