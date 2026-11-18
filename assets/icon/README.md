<a id="korean"></a>

# 앱 아이콘 (`assets/icon/`)

**한국어** · [English](#english)

> **기준일:** 2026-11-18

<!-- 2026-11-18 오너: 한국어 설명은 존댓말(~습니다)로 — 반말(~다) 문장만 바꿨고 내용은 그대로다. -->
<!-- 2026-11-18 (#21): 아이콘 원본을 SVG(원본-소프트3D.svg, QuiverAI Arrow)에서 v1.3 테마 그림체의 일러스트로 바꿨다.
     옛 SVG 는 git 기록에 있다: git show 271d58c:assets/icon/원본-소프트3D.svg -->

## 파일

| 파일 | 역할 |
|---|---|
| `원본-테마.jpg` | 원본. 이미지 AI(Seedream 5.5)가 그린 2048×2048 그림입니다. 청소 화면 테마와 같은 강아지·고양이가 키 하나 뒤에서 빼꼼 보고, 고양이가 천으로 키를 닦습니다 |
| `make-icon.sh` | 원본 그림에서 `AppIcon.icns` 까지 한 번에 다시 만드는 스크립트 |
| `mask.swift` | 정사각 그림에 macOS 규격(모서리 곡선 + 1024 안에 824)을 입히고, 크기별 비교 시트를 만듭니다 |
| `AppIcon.icns` | 빌드에 쓰이는 아이콘 — `build.sh` 가 앱 번들에 복사합니다 |
| `AppIcon-1024.png` | macOS 규격을 입힌 1024 — `.icns` 와 256 의 재료 |
| `AppIcon-256.png` | 저장소 첫 화면(README) 머리의 아이콘 |
| `검증-크기별.png` | 자른 그림과 결과를 256~16px 로 줄여 나란히 놓은 확인용 시트 |

## 다시 만들기

```bash
assets/icon/make-icon.sh <출력폴더>
```

- macOS 에 들어 있는 `sips` · `iconutil` 과 `swift`(Xcode 또는 Command Line Tools)만 씁니다.
- **커밋된 파일은 덮어쓰지 않습니다.** 결과는 `<출력폴더>` 에(중간 산출물은 `<출력폴더>/work/` 에) 쓰고,
  끝에 커밋된 네 파일과 바이트 단위로 대조해 보여 줍니다. `assets/icon` 자신을 출력 폴더로 주면 멈춥니다.
- 아이콘을 실제로 바꾸려면 `검증-크기별.png` 를 눈으로 확인한 뒤 네 파일을 직접 복사합니다.
  `cp <출력폴더>/{AppIcon.icns,AppIcon-1024.png,AppIcon-256.png,검증-크기별.png} assets/icon/`

스크립트가 하는 일:

| 단계 | 명령 | 이유 |
|---|---|---|
| ① 원본 크기 확인 | `sips -g pixelWidth -g pixelHeight` | 자르는 위치가 2048 원본 기준 숫자라서, 크기가 다른 그림이면 멈춥니다 |
| ② 정사각 자르기 | `sips -c 1720 1720 --cropOffset 174 185` | 원본은 위아래 여백이 약 22% 씩이라 아이콘이 비어 보입니다. 한 변 1720, 가운데 (1045, 1034) 로 잘라 위아래를 약 16% 로 줄입니다. 그림 속 내용이 가로로 길어서(폭 1524 × 높이 1164) 더 자르면 좌우가 먼저 잘립니다 |
| ③ macOS 규격 | `swift mask.swift <자른.png> <출력-1024.png> [<비교시트.png>]` | 이미지 AI 는 macOS 모서리 곡선을 정확히 못 그려서, 정사각으로 받아 코드로 깎습니다. 바깥은 투명(알파 0)이 됩니다 |
| ④ `.icns` | `sips -z` 로 16~1024 크기별 PNG → `iconutil -c icns` | macOS 가 크기마다 골라 쓰는 한 묶음 |
| ⑤ README 용 | `sips -z 256 256` | README 가 열릴 때마다 1024 를 받지 않게 |

- `sips` 의 `--cropOffset` 은 "위 왼" 순서입니다. `0 0` 을 주면 무시되고 가운데로 잘립니다(2026-11-18 실측). 여기 값은 0 이 아닙니다.

## 재현되는 것과 안 되는 것

- **2026-11-18 실측:** macOS 27.2.1 에서 `make-icon.sh` 를 다시 돌리면 `AppIcon.icns` · `AppIcon-1024.png` ·
  `AppIcon-256.png` · `검증-크기별.png` 네 파일 모두 커밋된 파일과 **바이트 단위로 같습니다**.
- **다른 macOS 에서는 다를 수 있습니다.** JPEG 를 읽는 `sips`, 비교 시트 글자의 시스템 폰트, PNG 인코더가
  모두 macOS 에 딸려 있어서 버전이 바뀌면 결과가 달라질 수 있습니다.
  그때는 스크립트가 "다르다"고 알려 주므로 `검증-크기별.png` 를 보고 판단합니다.
- **원본 그림 자체는 다시 만들 수 없습니다.** 이미지 AI 의 결과물이라 같은 요청을 다시 넣어도 같은 그림이
  나오지 않습니다. 이 JPEG 가 원본입니다(생성 결과 PNG 를 품질 92 JPEG 로 저장 — 저장소 무게를 줄이려고).

---

<a id="english"></a>

# App icon (`assets/icon/`)

[한국어](#korean) · **English**

> **As of:** 2026-11-18

<!-- 2026-11-18 (#21): the source changed from an SVG (원본-소프트3D.svg, QuiverAI Arrow) to an illustration in the
     style of the v1.3 themes. The old SVG is in git history: git show 271d58c:assets/icon/원본-소프트3D.svg -->

## Files

| File | Role |
|---|---|
| `원본-테마.jpg` | The source ("original, theme"). A 2048×2048 illustration drawn by an image AI (Seedream 5.5): the same dog and cat as the cleaning-screen themes peek out from behind a single key while the cat wipes it with a cloth |
| `make-icon.sh` | Regenerates everything from the source illustration up to `AppIcon.icns` in one go |
| `mask.swift` | Applies the macOS shape to a square image (rounded corners + 824 inside a 1024 canvas) and draws a size comparison sheet |
| `AppIcon.icns` | The icon the build uses — `build.sh` copies it into the app bundle |
| `AppIcon-1024.png` | The 1024 icon with the macOS shape applied — the input for the `.icns` and the 256 |
| `AppIcon-256.png` | The icon at the top of the repository's README |
| `검증-크기별.png` | Comparison sheet ("check by size"): the cropped art and the result scaled down from 256 to 16 px side by side |

## Regenerating

```bash
assets/icon/make-icon.sh <output dir>
```

- Uses only tools that ship with macOS (`sips`, `iconutil`) plus `swift` (Xcode or the Command Line Tools).
- **It never overwrites the committed files.** Results go to `<output dir>` (intermediate files to
  `<output dir>/work/`), and at the end it compares them byte for byte with the four committed files.
  It refuses to run if the output dir is `assets/icon` itself.
- To actually replace the icon, look at `검증-크기별.png` first, then copy the four files yourself.
  `cp <output dir>/{AppIcon.icns,AppIcon-1024.png,AppIcon-256.png,검증-크기별.png} assets/icon/`

What the script does:

| Step | Command | Why |
|---|---|---|
| ① Check the source size | `sips -g pixelWidth -g pixelHeight` | The crop position is given in pixels of the 2048 source, so it stops if the image has a different size |
| ② Square crop | `sips -c 1720 1720 --cropOffset 174 185` | The source has about 22% empty space above and below, which makes the icon look sparse. A 1720 square centred on (1045, 1034) brings that down to about 16%. The content is wide (1524 × 1164), so cropping further would cut the sides first |
| ③ macOS shape | `swift mask.swift <cropped.png> <output-1024.png> [<sheet.png>]` | Image AIs cannot draw the exact macOS corner curve, so the art is made square and cut in code. The outside becomes transparent (alpha 0) |
| ④ `.icns` | `sips -z` to PNGs from 16 to 1024 → `iconutil -c icns` | The set macOS picks from, one per size |
| ⑤ For the README | `sips -z 256 256` | So the README does not download the 1024 every time it opens |

- `sips --cropOffset` takes "top left". An offset of `0 0` is ignored and the crop is centred instead (measured
  2026-11-18); the values used here are not zero.

## What reproduces and what does not

- **Measured 2026-11-18:** on macOS 27.2.1, running `make-icon.sh` again produces `AppIcon.icns`,
  `AppIcon-1024.png`, `AppIcon-256.png` and `검증-크기별.png` **byte-identical** to the committed files.
- **Another macOS version may differ.** `sips` (which reads the JPEG), the system font on the comparison sheet and
  the PNG encoder all come with macOS, so a different version can change the output. The script tells you when a
  file differs; judge by looking at `검증-크기별.png`.
- **The source illustration itself cannot be regenerated.** It is an image AI's output, and the same request will
  not give the same picture again. This JPEG is the source (the generated PNG saved as a quality-92 JPEG to keep the
  repository small).
