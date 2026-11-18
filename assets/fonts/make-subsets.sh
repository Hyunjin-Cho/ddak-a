#!/bin/bash
# 일본어·중국어 청소 화면 글꼴 서브셋 만들기 — 2026-11-18 (#25)
#
# 원본 글꼴에서 "청소 화면 문구에 쓰는 글자 + 기본 라틴(U+0020–007E) + 자주 쓰는 문장부호"만 남겨 assets/fonts 에 쓴다.
# 문구를 바꾸면 이 스크립트를 다시 돌린다 — 안 돌리면 build.sh 의 글자 검사(check-overlay-glyphs.swift)가 빌드를 멈춘다.
#
# 쓰는 법:  bash assets/fonts/make-subsets.sh <원본 글꼴 폴더>
#   원본은 저장소에 넣지 않는다(합 47MB). 받는 곳과 SHA-256 은 assets/fonts/README.md · 아래 SRC_SHA 에 있다.
#   필요한 것: python3 + fontTools (pip install fonttools).
#
# 🔒 LXGW WenKai(간체)는 OFL 의 예약된 글꼴 이름('LXGW'·'霞鹜' 등)이 있다. 서브셋은 OFL 의 "수정본"이고,
#    이름을 그대로 쓰는 추가 허락은 웹폰트 배포에만 해당한다 → 간체 서브셋은 글꼴 이름을 "Ddaka Kai SC" 로 바꾼다.
#    저작권 줄(name 0)·라이선스는 그대로 둔다. Klee One · LXGW WenKai TC 는 예약된 이름이 없어 이름을 그대로 둔다.
set -euo pipefail
cd "$(dirname "$0")/../.."
SRC="${1:?원본 글꼴 폴더를 줘 — 예: bash assets/fonts/make-subsets.sh ~/Downloads/fonts}"
OUT="assets/fonts"
CHECK="assets/fonts/check-overlay-glyphs.swift"

python3 -c "import fontTools" 2>/dev/null || { echo "❌ fontTools 가 없어 — pip install fonttools"; exit 1; }

# 원본 확인 — 다른 판이 섞이면 모양·글자 수가 달라진다.
SRC_SHA="KleeOne-Regular.ttf bf4063f030cc2ae6adf0a11424a1888e5c0eb4438f1f6d02f52294af868e9b3a
LXGWWenKai-Regular.ttf 2d73eea94ad808999d90c0000c239a84a33b09d4bc6ab6c5b8bbf1eda8a7fc8b
LXGWWenKaiTC-Regular.ttf 4fcc5aec11cbbf737b0cfab7b63796f7f280087a7a656b2f13342cd5e5318d95"
while read -r file sha; do
    [ -f "$SRC/$file" ] || { echo "❌ $SRC/$file 가 없어"; exit 1; }
    got="$(shasum -a 256 "$SRC/$file" | cut -d' ' -f1)"
    [ "$got" = "$sha" ] || { echo "❌ $file 의 SHA-256 이 달라 — 받은 판이 README 와 다르다 ($got)"; exit 1; }
done <<< "$SRC_SHA"
echo "✓ 원본 3개 SHA-256 일치"

PUNCT_JA="、。・「」『』（）！？：〜…ー　"
PUNCT_ZH="，。、：；！？“”‘’「」『』（）《》…—·　"

subset() {   # $1 원본 · $2 결과 · $3 언어 · $4 덧붙일 문장부호
    local text
    text="$(swift "$CHECK" Sources/ddaka/main.swift --print "$3")$4"
    python3 -m fontTools.subset "$SRC/$1" --output-file="$OUT/$2" --text="$text" --unicodes="U+0020-007E" \
        --layout-features+=palt,halt --name-IDs='*' --name-languages='*' --name-legacy
    echo "✓ $2 — $3 글자 $(printf '%s' "$text" | python3 -c 'import sys; print(len(set(sys.stdin.read())))')개 + 기본 라틴"
}

subset KleeOne-Regular.ttf      KleeOne-Regular.ttf      ja      "$PUNCT_JA"
subset LXGWWenKai-Regular.ttf   DdakaKaiSC-Regular.ttf   zh-Hans "$PUNCT_ZH"
subset LXGWWenKaiTC-Regular.ttf LXGWWenKaiTC-Regular.ttf zh-Hant "$PUNCT_ZH"

# 간체 서브셋 이름 바꾸기 — 글꼴 이름이 들어가는 name 레코드(모든 언어)를 지우고 새 이름으로 다시 쓴다.
python3 -I - "$OUT/DdakaKaiSC-Regular.ttf" <<'PY'
import sys
from fontTools.ttLib import TTFont
path = sys.argv[1]
f = TTFont(path)
name = f["name"]
NAME_IDS = {1, 3, 4, 6, 16, 17, 18, 21, 22, 25}
name.names = [r for r in name.names if r.nameID not in NAME_IDS]
new = {
    1: "Ddaka Kai SC",
    3: "Ddaka Kai SC Regular; ddak-a subset 2026-11-18",   # 출처는 이름 자리가 아니라 설명(name 10)에 적는다
    4: "Ddaka Kai SC Regular",
    6: "DdakaKaiSC-Regular",
    16: "Ddaka Kai SC",
    17: "Regular",
}
for nid, value in new.items():
    name.setName(value, nid, 3, 1, 0x409)   # Windows · 영어
    name.setName(value, nid, 1, 0, 0)       # Mac · 영어
desc = ("Subset of LXGW WenKai 1.530 (SIL OFL 1.1) with only the characters ddak-a shows. "
        "Renamed because the original declares Reserved Font Names.")
name.names = [r for r in name.names if r.nameID != 10]
name.setName(desc, 10, 3, 1, 0x409)
name.setName(desc, 10, 1, 0, 0)
left = [(r.nameID, r.toUnicode()) for r in name.names if r.nameID in NAME_IDS and any(w in r.toUnicode() for w in ("LXGW", "霞鹜", "霞鶩", "落霞孤"))]
assert not left, left
f.save(path)
print("✓ DdakaKaiSC-Regular.ttf 이름 바꿈 (PostScript: DdakaKaiSC-Regular)")
PY

swift "$CHECK" Sources/ddaka/main.swift "$OUT"
ls -l "$OUT"/*.ttf
