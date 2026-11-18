# 청소 화면 글꼴 · Cleaning-screen fonts

> **기준일:** 2026-11-18

[한국어](#한국어) · [English](#english)

## 한국어

청소 화면(키보드가 막혀 있는 동안의 화면)에 쓰는 글꼴입니다. 모두 SIL Open Font License 1.1 을 따르며, 앱에는 **화면에 나오는 글자만 남긴 서브셋**을 넣습니다.

| 파일 | 쓰는 언어 | 원본 | 라이선스 |
|---|---|---|---|
| `GowunDodum-Regular.ttf` | 한국어 · 영어 · 남은 시간 숫자(모든 언어) | [고운돋움 Gowun Dodum](https://github.com/yangheeryu/Gowun-Dodum) — KS X 1001 한글 2,350자 + 라틴 | `OFL-GowunDodum.txt` |
| `KleeOne-Regular.ttf` | 일본어 | [Klee One](https://github.com/fontworks-fonts/Klee) 1.100 | `OFL-KleeOne.txt` |
| `DdakaKaiSC-Regular.ttf` | 중국어 간체 | [LXGW WenKai 霞鹜文楷](https://github.com/lxgw/LxgwWenKai) 1.530 — **이름을 바꾼 서브셋** | `OFL-LXGWWenKai.txt` |
| `LXGWWenKaiTC-Regular.ttf` | 중국어 번체 | [LXGW WenKai TC 霞鶩文楷 TC](https://github.com/lxgw/LxgwWenkaiTC) 1.330 | `OFL-LXGWWenKaiTC.txt` |

- `⌘⇧9` 기호만은 모든 언어에서 맥에 들어 있는 Apple SD Gothic Neo 로 그립니다(넣는 글꼴이 아닙니다).
- 넣은 글꼴을 찾지 못하면 앱은 예전처럼 맥 글꼴(히라기노 둥근 고딕 · 핑팡)로, 그것도 없으면 시스템 글꼴로 물러납니다.

### 간체 글꼴 이름을 바꾼 이유

LXGW WenKai 는 OFL 의 **예약된 글꼴 이름**(`LXGW` · `霞鹜` · `霞鶩` · `落霞孤鹜` · `落霞孤鶩`)을 두고 있습니다. 글자를 덜어 낸 서브셋은 OFL 이 말하는 "수정본"이고, 수정본이 원래 이름을 그대로 쓸 수 있는 추가 허락은 웹폰트로 배포할 때뿐입니다. 그래서 앱에 넣는 간체 서브셋은 글꼴 이름만 **Ddaka Kai SC** 로 바꿨습니다. 글자 모양은 원본 그대로이고, 저작권 표시와 라이선스 원문은 그대로 둡니다. Klee One · LXGW WenKai TC · 고운돋움은 예약된 이름이 없어 이름을 바꾸지 않았습니다(각 OFL 원문 첫 줄).

### 다시 만들기

청소 화면 문구를 바꾸면 일본어·중국어 서브셋을 다시 만들어야 합니다. 안 만들면 `build.sh` 의 글자 검사가 빌드를 멈춥니다.

1. 원본 3개를 받습니다(저장소에는 넣지 않습니다 — 합 47MB).
   - Klee One: `https://raw.githubusercontent.com/google/fonts/main/ofl/kleeone/KleeOne-Regular.ttf`
   - LXGW WenKai: `https://github.com/lxgw/LxgwWenKai/releases/download/v1.530/LXGWWenKai-Regular.ttf`
   - LXGW WenKai TC: `https://raw.githubusercontent.com/google/fonts/main/ofl/lxgwwenkaitc/LXGWWenKaiTC-Regular.ttf`
2. `bash assets/fonts/make-subsets.sh <받은 폴더>` — 원본 SHA-256 을 확인한 뒤 서브셋을 만들고, 간체 이름을 바꾸고, 글자 검사까지 돌립니다(python3 + fontTools 필요).
3. 원본의 판이 바뀌었으면 `make-subsets.sh` 의 SHA-256 과 이 표의 판 번호를 같이 고칩니다.

| 원본 | SHA-256 |
|---|---|
| `KleeOne-Regular.ttf` 1.100 | `bf4063f030cc2ae6adf0a11424a1888e5c0eb4438f1f6d02f52294af868e9b3a` |
| `LXGWWenKai-Regular.ttf` 1.530 | `2d73eea94ad808999d90c0000c239a84a33b09d4bc6ab6c5b8bbf1eda8a7fc8b` |
| `LXGWWenKaiTC-Regular.ttf` 1.330 | `4fcc5aec11cbbf737b0cfab7b63796f7f280087a7a656b2f13342cd5e5318d95` |

`check-overlay-glyphs.swift` 는 `Sources/ddaka/main.swift` 에서 청소 화면 문구 4개(`cleaning` · `mouseHint` · `done` · `shortcutHint`)를 읽어, 언어마다 그 언어 글꼴에 모든 글자가 있는지 봅니다. 언어 ↔ 글꼴 짝은 `Themes.swift` 의 `overlayFont` 와 같아야 합니다.

---

## English

These are the fonts for the cleaning screen (the screen shown while the keyboard is locked). All are under the SIL Open Font License 1.1, and the app ships **subsets that keep only the characters the screen shows**.

| File | Used for | Source | Licence |
|---|---|---|---|
| `GowunDodum-Regular.ttf` | Korean · English · the countdown digits (every language) | [Gowun Dodum](https://github.com/yangheeryu/Gowun-Dodum) — the 2,350 Hangul syllables of KS X 1001 + Latin | `OFL-GowunDodum.txt` |
| `KleeOne-Regular.ttf` | Japanese | [Klee One](https://github.com/fontworks-fonts/Klee) 1.100 | `OFL-KleeOne.txt` |
| `DdakaKaiSC-Regular.ttf` | Simplified Chinese | [LXGW WenKai](https://github.com/lxgw/LxgwWenKai) 1.530 — **a renamed subset** | `OFL-LXGWWenKai.txt` |
| `LXGWWenKaiTC-Regular.ttf` | Traditional Chinese | [LXGW WenKai TC](https://github.com/lxgw/LxgwWenkaiTC) 1.330 | `OFL-LXGWWenKaiTC.txt` |

- Only the `⌘⇧9` symbols are drawn with Apple SD Gothic Neo, which comes with macOS (it is not shipped).
- If a bundled font cannot be found, the app falls back to the macOS fonts it used before (Hiragino Maru Gothic · PingFang), and then to the system font.

### Why the Simplified Chinese font is renamed

LXGW WenKai declares OFL **Reserved Font Names** (`LXGW`, `霞鹜`, `霞鶩`, `落霞孤鹜`, `落霞孤鶩`). A subset is a "Modified Version" under the OFL, and the extra permission to keep the original name applies only to web-font delivery. So the Simplified Chinese subset in the app is renamed to **Ddaka Kai SC**. The glyphs are unchanged, and the copyright notice and licence text are kept. Klee One, LXGW WenKai TC and Gowun Dodum declare no reserved names, so they keep their names (first line of each OFL text).

### Rebuilding the subsets

If the cleaning-screen strings change, rebuild the Japanese and Chinese subsets. Otherwise the glyph check in `build.sh` stops the build.

1. Download the three originals (they are not in the repository — 47 MB in total). The URLs are in the Korean section above.
2. Run `bash assets/fonts/make-subsets.sh <download folder>`. It checks the SHA-256 of each original, builds the subsets, renames the Simplified Chinese one and runs the glyph check (needs python3 + fontTools).
3. If an original has a new version, update the SHA-256 in `make-subsets.sh` and the version numbers here together.

`check-overlay-glyphs.swift` reads the four cleaning-screen strings (`cleaning`, `mouseHint`, `done`, `shortcutHint`) from `Sources/ddaka/main.swift` and checks that every character is in that language's font. The language-to-font pairs must match `overlayFont` in `Themes.swift`.
