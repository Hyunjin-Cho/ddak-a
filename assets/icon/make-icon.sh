#!/bin/bash
# 닦아 앱 아이콘을 원본 SVG 에서 AppIcon.icns 까지 다시 만든다 — 2026-09-23 (#11)
#
# 사용법: assets/icon/make-icon.sh <출력폴더>
#
# 🚨 2026-09-23 (#11): 이 과정은 그동안 어디에도 적혀 있지 않아서 저장소만으로는 아이콘을 다시 만들 수 없었다.
#   2026-09-22 에 아이콘을 만들 때 실제로 쓴 명령(당시 작업 기록으로 확인)을 그대로 옮겼고, 2026-09-23 에
#   다시 돌려 커밋된 네 파일(AppIcon.icns · AppIcon-1024.png · AppIcon-256.png · 검증-크기별.png)과
#   바이트 단위로 같게 나오는 것을 확인했다.
# 🔒 2026-09-23 (#11): 커밋된 파일(이 폴더)은 덮어쓰지 않는다. 결과는 <출력폴더> 에만 쓰고, 끝에 대조만 한다.
#   아이콘을 실제로 바꾸려면 결과(특히 검증-크기별.png)를 눈으로 확인한 뒤 직접 복사한다.
# macOS 에 들어 있는 도구(qlmanage · sips · iconutil)와 swift(Xcode 또는 Command Line Tools)만 쓴다.
set -euo pipefail

ICON_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SVG="$ICON_DIR/원본-소프트3D.svg"

usage() {
    echo "사용법: $0 <출력폴더>"
    echo "  원본-소프트3D.svg 에서 AppIcon.icns 까지 만들어 <출력폴더> 에 쓴다."
    echo "  이 폴더(assets/icon)의 커밋된 파일은 건드리지 않고, 끝에 대조만 한다."
}

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
    usage >&2
    exit 2
fi
case "$1" in
    -h|--help) usage; exit 0 ;;
esac

for tool in qlmanage sips iconutil swift; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ '$tool' 을 찾지 못했어 — macOS 기본 도구와 swift(Xcode 또는 Command Line Tools)가 필요하다" >&2
        exit 1
    fi
done
if [ ! -f "$SVG" ]; then
    echo "❌ 원본 SVG 가 없어: $SVG" >&2
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

echo "① 여백 잘라내기 — viewBox 를 0 0 1024 1024 로"
# 원본 SVG 는 사방에 25.6 씩 빈 여백을 두고 있다(viewBox -25.6 -25.6 1075.2 1075.2). 그림(배경 사각형)은
# 0~1024 에만 있고, Quick Look 은 빈 곳을 흰색으로 채운다 — 그대로 그리면 1024 렌더 가장자리에 24px 흰 띠가
# 생기고, mask.swift 를 거치면 모서리 곡선 안쪽에 약 19px 흰 테로 남는다(2026-09-23 실측).
TRIM_SVG="$WORK/icon-trim.svg"
sed -e 's|viewBox="-25.6 -25.6 1075.2 1075.2"|viewBox="0 0 1024 1024"|' \
    -e 's|width="1075.2" height="1075.2"|width="1024" height="1024"|' \
    "$SVG" > "$TRIM_SVG"
# 원본 SVG 를 바꿨는데 머리 모양이 다르면 sed 가 아무 일도 안 하고 조용히 지나간다 → 확인하고 멈춘다
if grep -q '1075\.2' "$TRIM_SVG" || ! grep -q 'viewBox="0 0 1024 1024"' "$TRIM_SVG"; then
    echo "❌ 여백을 잘라내지 못했어 — 원본 SVG 의 <svg ...> 머리가 예상(1075.2 · -25.6)과 다르다." >&2
    echo "   새 SVG 라면 그 SVG 의 viewBox 에 맞게 이 단계를 고쳐야 한다." >&2
    exit 1
fi

echo "② SVG → 1024 PNG — Quick Look(qlmanage)"
RENDER="$TRIM_SVG.png"      # qlmanage 는 원래 파일 이름 뒤에 .png 를 붙여 쓴다
rm -f "$RENDER"
QL_LOG="$(qlmanage -t -s 1024 -o "$WORK" "$TRIM_SVG" 2>&1)" || true
if [ ! -s "$RENDER" ]; then
    echo "❌ Quick Look 이 SVG 를 그리지 못했어 ($RENDER 가 없다)" >&2
    echo "$QL_LOG" >&2
    exit 1
fi
SIZE="$(sips -g pixelWidth -g pixelHeight "$RENDER" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')"
if [ "$SIZE" != "1024x1024" ]; then
    echo "❌ 렌더 크기가 1024x1024 가 아니라 $SIZE 다: $RENDER" >&2
    exit 1
fi

echo "③ macOS 규격 입히기 — mask.swift (모서리 곡선 + 1024 안에 824)"
swift "$ICON_DIR/mask.swift" "$RENDER" "$OUT/AppIcon-1024.png" "$OUT/검증-크기별.png"

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
    echo "   원본 SVG 를 바꾸지 않았는데도 다르면 macOS 차이일 가능성이 크다 — SVG 를 그리는 Quick Look,"
    echo "   비교 시트의 시스템 폰트, PNG 인코더는 macOS 에 딸려 있어서 버전이 바뀌면 결과가 달라질 수 있다."
    echo "   검증-크기별.png 를 눈으로 확인한 뒤에 바꿀지 정한다."
fi
# 2026-09-23: 복사 명령을 경로째 찍어 주지 않는다 — 저장소 경로의 '!'(ddak-a!)는 대화형 셸에 붙여 넣으면
#   큰따옴표 안에서도 히스토리 확장으로 깨지고, bash 3.2 의 printf %q 는 한글 경로를 망가뜨린다(둘 다 실측).
echo "   아이콘을 이 결과로 바꾸려면 확인한 뒤 네 파일을 직접 assets/icon/ 에 복사한다:"
echo "   AppIcon.icns · AppIcon-1024.png · AppIcon-256.png · 검증-크기별.png"
