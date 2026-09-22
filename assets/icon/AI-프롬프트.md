# 닦아 앱 아이콘 — 이미지 AI 프롬프트 모음

> **기준일:** 2026-09-22
> 이 폴더의 `variant1~3-1024.png` 는 Swift(`makeicon.swift`)로 직접 그린 1차 시안이다.
> 아래는 이미지 생성 AI(Nano Banana · GPT Image · Midjourney · Flux 등)에 그대로 넣을 프롬프트.

## 0. 프롬프트를 쓸 때 내가 잡은 기준

1. **주제는 두 개로 고정** — 키보드 + 반짝임. 셋 이상 넣으면 작은 크기에서 전부 뭉개진다.
2. **색은 숫자로 지정** — 앱 실행 화면 오버레이가 `#87CEEB` 하늘색이라 아이콘도 같은 색으로 묶는다.
   "하늘색"이라고만 쓰면 AI가 매번 다른 파랑을 낸다.
3. **구도를 말로 고정** — 중앙 배치, 넉넉한 여백. 안 쓰면 AI가 화면을 꽉 채워서 Dock에서 답답해진다.
4. **글자는 금지** — 이미지 AI는 한글을 거의 못 쓰고, 앱 아이콘에 글자가 들어가면 작은 크기에서 죽는다.
5. **모서리(squircle)는 AI에게 맡기지 않는다** — 정확한 macOS 모서리 곡선을 AI는 못 만든다.
   **정사각형 꽉 찬 그림으로 뽑고, 모서리 깎기는 내가 코드로 정확히 처리**하는 게 낫다.
6. **반드시 32px로 줄여서 확인** — 아이콘의 진짜 승부처는 Dock 크기다. 크게만 보고 고르면 실패한다.

---

## 1. 미니멀 플랫 (시안 A 계열 · 가장 안전)

```
A macOS app icon design, flat vector illustration, perfectly square composition,
full-bleed background of a smooth vertical gradient in sky blue (#87CEEB at top,
#4AA1D1 at bottom). Centered white simplified keyboard seen straight-on, only
4 columns by 3 rows of large rounded keys plus one wide spacebar — chunky and
clearly readable when shrunk down. Two or three crisp white four-point sparkle
stars floating at the upper right of the keyboard, one large and one small.
Clean, minimal, high contrast, no text, no letters, no shadows outside the icon,
no photorealism, no gradients inside the keys. Generous empty margin around the
keyboard. 1024x1024.
```

## 2. 소프트 3D (요즘 macOS 아이콘 트렌드)

```
A modern macOS Big Sur style app icon, soft 3D render, perfectly square,
full-bleed sky blue (#87CEEB) gradient background with a subtle glossy highlight
sweeping across the upper half. A white keyboard floating slightly above the
surface at a gentle top-down angle, with soft realistic drop shadow beneath it,
rounded chunky keys, very few keys (4x3 plus spacebar) so it stays legible small.
Glossy white sparkles with soft glow at the upper right. Smooth matte plastic
material, soft studio lighting, clean and friendly. No text, no letters,
no brand marks, no clutter. Centered with wide margins. 1024x1024.
```

## 3. 유리 질감 (macOS Tahoe / Liquid Glass 계열)

```
A macOS app icon in translucent frosted glass style, perfectly square,
full-bleed sky blue (#87CEEB) background. A keyboard rendered as clear glass
with soft refraction and subtle rim light, sitting over the blue surface,
only a few large rounded keys so the shape reads instantly at small sizes.
Delicate white light sparkles with bloom at the upper right corner of the
keyboard. Layered depth, soft inner shadows, glassy specular highlights,
premium Apple design language. No text, no letters, no photorealistic details.
Centered, generous padding. 1024x1024.
```

## 4. 개념 강조 — "닦는다"를 직접 보여주기

```
A macOS app icon, flat vector illustration, perfectly square, full-bleed sky blue
(#87CEEB) gradient background. A white simplified keyboard in the lower center
with only a few large rounded keys, and a soft white microfiber cloth sweeping
diagonally across the top of the keyboard leaving a bright glossy streak behind it.
A few small white sparkles along the cleaned streak. Playful, friendly, very clean.
No text, no letters, no hands, no human figures, no clutter. Centered composition
with wide margins. 1024x1024.
```

---

## 뽑은 다음

- **정사각 PNG(1024x1024)** 그대로 주면 된다. 모서리 깎기·크기별 리사이즈·`.icns` 변환은 내가 처리한다.
- 배경이 투명한 그림(키보드만)으로 뽑아도 된다. 그 경우 배경 하늘색은 내가 코드로 깔면
  색이 앱 실행 화면과 **정확히** 일치한다.
- 여러 장 뽑았으면 전부 주면 된다. 32px까지 줄인 비교 시트를 만들어서 같이 보자.
