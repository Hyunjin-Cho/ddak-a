<a id="korean"></a>

# 앱 아이콘 (`assets/icon/`)

**한국어** · [English](#english)

> **기준일:** 2026-09-23

## 파일

| 파일 | 역할 |
|---|---|
| `원본-소프트3D.svg` | 원본. 이미지 AI(QuiverAI 의 Arrow)가 만든 SVG 를 손대지 않고 둔 것 |
| `make-icon.sh` | 원본 SVG 에서 `AppIcon.icns` 까지 한 번에 다시 만드는 스크립트 |
| `mask.swift` | 정사각 PNG 에 macOS 규격(모서리 곡선 + 1024 안에 824)을 입히고, 크기별 비교 시트를 만든다 |
| `AppIcon.icns` | 빌드에 쓰이는 아이콘 — `build.sh` 가 앱 번들에 복사한다 |
| `AppIcon-1024.png` | macOS 규격을 입힌 1024 — `.icns` 와 256 의 재료 |
| `AppIcon-256.png` | 저장소 첫 화면(README) 머리의 아이콘 |
| `검증-크기별.png` | 원본과 결과를 256~16px 로 줄여 나란히 놓은 확인용 시트 |

## 다시 만들기

```bash
assets/icon/make-icon.sh <출력폴더>
```

- macOS 에 들어 있는 `qlmanage` · `sips` · `iconutil` 과 `swift`(Xcode 또는 Command Line Tools)만 쓴다.
- **커밋된 파일은 덮어쓰지 않는다.** 결과는 `<출력폴더>` 에(중간 산출물은 `<출력폴더>/work/` 에) 쓰고,
  끝에 커밋된 네 파일과 바이트 단위로 대조해 보여 준다. `assets/icon` 자신을 출력 폴더로 주면 멈춘다.
- 아이콘을 실제로 바꾸려면 `검증-크기별.png` 를 눈으로 확인한 뒤 네 파일을 직접 복사한다.
  `cp <출력폴더>/{AppIcon.icns,AppIcon-1024.png,AppIcon-256.png,검증-크기별.png} assets/icon/`

스크립트가 하는 일:

| 단계 | 명령 | 이유 |
|---|---|---|
| ① 여백 잘라내기 | `sed` 로 `viewBox` 를 `0 0 1024 1024` 로 | 원본은 사방에 25.6 씩 여백이 있다. 그대로 그리면 Quick Look 이 그 자리를 흰색으로 채워서, 모서리 곡선 안쪽에 약 19px 흰 테가 남는다 |
| ② SVG → PNG | `qlmanage -t -s 1024` | macOS 에 기본으로 있는 SVG 렌더러(Quick Look 썸네일). 결과 이름은 `<원래 이름>.png` |
| ③ macOS 규격 | `swift mask.swift <입력.png> <출력-1024.png> [<비교시트.png>]` | 이미지 AI 는 macOS 모서리 곡선을 정확히 못 그려서, 정사각으로 받아 코드로 깎는다 |
| ④ `.icns` | `sips -z` 로 16~1024 크기별 PNG → `iconutil -c icns` | macOS 가 크기마다 골라 쓰는 한 묶음 |
| ⑤ README 용 | `sips -z 256 256` | README 가 열릴 때마다 1024 를 받지 않게 |

## 재현되는 것과 안 되는 것

- **2026-09-23 실측:** macOS 27.0 에서 `make-icon.sh` 를 돌리면 `AppIcon.icns` · `AppIcon-1024.png` ·
  `AppIcon-256.png` · `검증-크기별.png` 네 파일 모두 커밋된 파일과 **바이트 단위로 같다**
  (`.icns` 를 `iconutil -c iconset` 으로 풀어 본 크기별 PNG 도 모두 같다).
- **다른 macOS 에서는 다를 수 있다.** SVG 를 그리는 Quick Look, 비교 시트 글자의 시스템 폰트,
  PNG 인코더가 모두 macOS 에 딸려 있어서 버전이 바뀌면 결과가 달라질 수 있다.
  그때는 스크립트가 "다르다"고 알려 주므로 `검증-크기별.png` 를 보고 판단한다.
- **SVG 자체는 다시 만들 수 없다.** 이미지 AI 의 결과물이라 같은 요청을 다시 넣어도 같은 그림이
  나오지 않는다. 이 SVG 가 원본이다.

---

<a id="english"></a>

# App icon (`assets/icon/`)

[한국어](#korean) · **English**

> **As of:** 2026-09-23

## Files

| File | Role |
|---|---|
| `원본-소프트3D.svg` | The source ("original, soft 3D"). The SVG made by an image AI (Arrow, by QuiverAI), kept untouched |
| `make-icon.sh` | Regenerates everything from the source SVG up to `AppIcon.icns` in one go |
| `mask.swift` | Applies the macOS shape to a square PNG (rounded corners + 824 inside a 1024 canvas) and draws a size comparison sheet |
| `AppIcon.icns` | The icon the build uses — `build.sh` copies it into the app bundle |
| `AppIcon-1024.png` | The 1024 icon with the macOS shape applied — the input for the `.icns` and the 256 |
| `AppIcon-256.png` | The icon at the top of the repository's README |
| `검증-크기별.png` | Comparison sheet ("check by size"): source and result scaled down from 256 to 16 px side by side |

## Regenerating

```bash
assets/icon/make-icon.sh <output dir>
```

- Uses only tools that ship with macOS (`qlmanage`, `sips`, `iconutil`) plus `swift` (Xcode or the
  Command Line Tools).
- **It never overwrites the committed files.** Results go to `<output dir>` (intermediate files to
  `<output dir>/work/`), and at the end it compares them byte for byte with the four committed files.
  It refuses to run if the output dir is `assets/icon` itself.
- To actually replace the icon, look at `검증-크기별.png` first, then copy the four files yourself.
  `cp <output dir>/{AppIcon.icns,AppIcon-1024.png,AppIcon-256.png,검증-크기별.png} assets/icon/`

What the script does:

| Step | Command | Why |
|---|---|---|
| ① Trim the margin | `sed` sets `viewBox` to `0 0 1024 1024` | The source has a 25.6 margin on every side. Rendered as is, Quick Look fills it with white, which ends up as a white rim of about 19 px inside the rounded corners |
| ② SVG → PNG | `qlmanage -t -s 1024` | The SVG renderer that ships with macOS (Quick Look thumbnails). The output is named `<original name>.png` |
| ③ macOS shape | `swift mask.swift <input.png> <output-1024.png> [<sheet.png>]` | Image AIs cannot draw the exact macOS corner curve, so the art is made square and cut in code |
| ④ `.icns` | `sips -z` to PNGs from 16 to 1024 → `iconutil -c icns` | The set macOS picks from, one per size |
| ⑤ For the README | `sips -z 256 256` | So the README does not download the 1024 every time it opens |

## What reproduces and what does not

- **Measured 2026-09-23:** on macOS 27.0, `make-icon.sh` produces `AppIcon.icns`, `AppIcon-1024.png`,
  `AppIcon-256.png` and `검증-크기별.png` **byte-identical** to the committed files (and every PNG
  inside the `.icns`, unpacked with `iconutil -c iconset`, is identical too).
- **Another macOS version may differ.** Quick Look (which renders the SVG), the system font on the
  comparison sheet and the PNG encoder all come with macOS, so a different version can change the
  output. The script tells you when a file differs; judge by looking at `검증-크기별.png`.
- **The SVG itself cannot be regenerated.** It is an image AI's output, and the same request will not
  give the same picture again. This SVG is the source.
