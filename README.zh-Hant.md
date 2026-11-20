<p align="center">
  <img src="assets/icon/AppIcon-256.png" width="128" alt="ddaka 應用程式圖像">
</p>

# ddaka（닦아）

[한국어](README.md#korean) · [English](README.md#english) · [日本語](README.ja.md) · [简体中文](README.zh-Hans.md) · **繁體中文**

> **基準日期：** 2026-11-20
> **狀態：** **v1.3 已發布** — 可在 [Releases](https://github.com/Hyunjin-Cho/ddaka/releases) 下載（應用程式與 DMG 皆已通過 Apple 公證）

<!-- 2026-11-18 (#27): README.md(한국어·영어)의 중국어 번체판(대만 표기). README.md 를 고치면 이 파일도 같이 고친다.
     상태 줄 규칙은 README.md 맨 위 주석과 같다(새 버전 동작을 적는 문장과 상태 줄은 같이 움직인다).
     메뉴·설정 이름(捷徑 · 打開App · 捷徑詳細資訊 · 加入鍵盤快速鍵 · 輔助使用快速鍵 · 關於這台Mac ·
     輔助使用 · 輸入監控)은 macOS 27.0 · 단축어 10.0 의 시스템 문자열 표(zh_TW)에서 확인했다.
     홍콩(zh_HK)은 輸入監察 · 私隱與保安 — 처음 나오는 곳 · 요구 사항 · 표시 언어 절에 같이 적는다(#32).
     앱 문구(要啟動 ddaka 嗎？ · 開始 · 完成)는 Sources/ddaka/main.swift 의 번체 그대로. -->

這是一款 macOS 工具程式：執行期間會**完全阻擋整個鍵盤**，這樣在擦拭 Mac 鍵盤時就算不小心按到按鍵，
輸入也不會傳到電腦。**滑鼠和觸控板照常可用。**

名稱 닦아（*ddaka*）在韓文裡是「擦一擦」的意思。

<p align="center">
  <b>macOS 12（Monterey）或以上版本</b> · <b>同時支援 Intel 與 Apple 晶片</b>
</p>

<p align="center">
  <img src="assets/screenshot.jpg" width="680" alt="ddaka 執行中的畫面">
  <br>
  <sub>執行中的畫面（v1.3）— 每次啟動都會從 10 幅插畫中選一幅，覆蓋已連接的<b>所有顯示器</b></sub>
</p>

<table align="center">
  <tr>
    <td align="center"><img src="assets/readme/themes/sunset.jpg" width="136" alt="晚霞"><br><sub>晚霞</sub></td>
    <td align="center"><img src="assets/readme/themes/beach.jpg" width="136" alt="海邊"><br><sub>海邊</sub></td>
    <td align="center"><img src="assets/readme/themes/busstop.jpg" width="136" alt="公車站"><br><sub>公車站</sub></td>
    <td align="center"><img src="assets/readme/themes/rain.jpg" width="136" alt="雨天"><br><sub>雨天</sub></td>
    <td align="center"><img src="assets/readme/themes/walk.jpg" width="136" alt="散步"><br><sub>散步</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/readme/themes/autumn.jpg" width="136" alt="秋天"><br><sub>秋天</sub></td>
    <td align="center"><img src="assets/readme/themes/night.jpg" width="136" alt="流星"><br><sub>流星</sub></td>
    <td align="center"><img src="assets/readme/themes/nap.jpg" width="136" alt="午睡"><br><sub>午睡</sub></td>
    <td align="center"><img src="assets/readme/themes/lookup.jpg" width="136" alt="仰望"><br><sub>仰望</sub></td>
    <td align="center"><img src="assets/readme/themes/snow.jpg" width="136" alt="雪"><br><sub>雪</sub></td>
  </tr>
</table>

## 安裝

1. 從 [Releases](https://github.com/Hyunjin-Cho/ddaka/releases) 下載 `.dmg`
2. 在開啟的視窗中，**把 `닦아` 拖到 `Applications` 檔案夾**
3. 從「應用程式」檔案夾啟動

**如果您一直在使用舊的 `ddak-a`** — 從 v1.3 起英文名稱由 `ddak-a` 改為 `ddaka`，新應用程式不會覆蓋舊的應用程式。請**先把「應用程式」檔案夾裡舊的 `ddak-a` 移到垃圾桶**，再把新應用程式拖進去。如果權限處於關閉狀態，應用程式會告訴您在哪裡開啟。

> ### ⚠️ 執行前請先移到「應用程式」檔案夾
>
> 從網路下載的應用程式如果在「應用程式」檔案夾**以外**執行，macOS 每次都會從一份新的暫存副本啟動它（App Translocation）。
> **從這個暫存位置執行的應用程式，無法保留「輔助使用」和「輸入監控」權限** — 就算開啟了，下次啟動又會變回關閉。
>
> **親自**把它移到「應用程式」檔案夾，就能解除這種狀態。如果一直放在「下載項目」或桌面，權限開幾次都留不住。
>
> 從 v1.1 起，應用程式會自己察覺這種情況，**在要求任何權限之前**提醒你，然後結束。

第一次啟動時會要求**輔助使用**和**輸入監控**（香港：輸入監察）權限。阻擋鍵盤需要這兩項。

## 運作方式

1. 啟動 → 出現「要啟動 ddaka 嗎？」確認
2. 檢查權限 — **輔助使用** + **輸入監控**（缺少時應用程式會自己要求）
3. 用全螢幕插畫覆蓋已連接的**所有顯示器**並開始倒數 — 每次啟動都會從 10 個場景中隨機挑一個（v1.3）
4. 以下任一情況先發生就結束
   - 點按 **「完成」** 按鈕 → 立即結束
   - 3 分鐘倒數結束 → 自動結束
   - **Cmd + Shift + 9（⌘⇧9）** → 應用程式自己偵測到後立即結束

## 用一個快速鍵啟動與結束（選用）

替 macOS 內建的**捷徑** App 設定鍵盤快速鍵，就能不點圖像直接啟動 ddaka。
把這個鍵設成 **⌘⇧9**，啟動鍵和結束鍵就是同一個 — **只要記住 ⌘⇧9 就夠了。**

1. 在**捷徑**中點按 **＋**，新增一個捷徑
2. 加入 **打開App** 動作，App 選擇 **닦아**
3. **捷徑詳細資訊**（ⓘ）→ **加入鍵盤快速鍵** → 按下 **⌘⇧9**

這樣一來：**⌘⇧9** → 確認視窗中點 **開始** → 開始清潔；清潔中按 **⌘⇧9** → 結束。

- 清潔中按下的 ⌘⇧9 會先被 ddaka 收到，所以捷徑不會再次啟動 ddaka
  （已在 macOS 27.0・捷徑 10.0 上以執行記錄確認。捷徑 App 從 macOS 12 起就有，但更早的版本未經確認）
- 用其他按鍵也能啟動，但**結束鍵永遠是 ⌘⇧9**

> 💡 這個方法由韓國 Naver 社群 [맥쓰사（用 Mac 的人們）](https://cafe.naver.com/inmacbook) 的 **봄물결（Bommulgyeol）** 提出，謝謝！

## 阻擋範圍

| 輸入 | 是否阻擋 |
|---|---|
| 內建鍵盤 | 阻擋 |
| 藍牙 / USB 外接鍵盤 | 阻擋 |
| 媒體鍵（亮度、音量等） | 阻擋 |
| Touch ID 鍵 | **會通過 — 由 macOS 處理，屬於正常行為。** 按一下會鎖定螢幕，快速連按三下會打開「輔助使用快速鍵」面板。解鎖後清潔畫面會繼續 |
| 🌐（fn）鍵 | **會通過** — 清潔畫面沒有輸入欄位，按下也不會發生任何事 |
| Cmd + Shift + 9（⌘⇧9） | 由應用程式接收並**立即結束**（不會傳給其他應用程式） |
| 滑鼠 / 觸控板 | 不阻擋 |

## 安全機制

對一個阻擋鍵盤的應用程式來說，最危險的故障是「一直不放開」。所以這裡疊了好幾層彼此獨立的機制。

- 3 分鐘倒數結束後正常結束
- 一個**獨立於倒數運作**的安全計時器，會在 190 秒時再試一次結束
- 萬一連這個計時器也失敗，**與應用程式主邏輯無關的背景監看程式**會數到 195 秒並結束行程。行程不在了，鍵盤阻擋也就解除了
- 結束按鈕顯示在**每一台顯示器**上，滑鼠在哪裡都按得到
- 版面會按比例縮小，在小螢幕上結束按鈕也不會被切掉
- **不會同時執行兩個。** 如果有兩個阻擋程式在執行，結束快速鍵只能關掉其中一個，另一個會繼續阻擋。
  已在 macOS 27 上確認，更早的版本未經確認 — 就算沒能防止，上面的各項自動解除也會在每個實例上各自生效

## 遇到問題時（記錄）

從 v1.2 起，ddaka 會把**每次清潔是怎麼結束的**寫進 macOS 記錄。如果鍵盤解除得太晚，或看起來不太對勁，
請在「終端機」執行下面的指令，並把輸出附在 [Issue](https://github.com/Hyunjin-Cho/ddaka/issues) 裡。

```bash
/usr/bin/log show --last 1h --predicate 'subsystem == "com.vismotive.ddaka"'
```

- `reason=` 後面的字就是結束原因 — `done-button`（完成按鈕）· `countdown`（3 分鐘）· `shortcut`（⌘⇧9）·
  `safety-timer`（190 秒安全計時器）· `screens-gone`（所有顯示器都不見了）
- 如果 195 秒強制結束生效，會看到 `hard kill`
- 從 v1.3 起，開始的那一行還會加上 `theme=`（顯示了哪幅插畫）和 `art=`（是否載入成功 — `false` 表示退回了素色天藍背景）
- 🔒 **絕不記錄按鍵內容。** 只記錄應用程式自己做了什麼 — 開始與結束、結束原因、權限狀態

## 自行建置

如何自行建置、如何製作經過公證的發布版本，以及專案結構，請見 [`docs/BUILDING.md`](docs/BUILDING.md#english)（韓文・英文）。

## 顯示語言

應用程式會自動跟隨 Mac 的系統語言，App 內沒有語言設定。

準確地說，它會使用系統「偏好的語言」列表中**本 App 支援、排在最前面的語言**。
如果第一項是不支援的語言（例如法文），第二項是繁體中文，就會顯示繁體中文。

| 系統語言 | 顯示為 |
|---|---|
| 한국어 | 韓文 |
| English | 英文 |
| 日本語 | 日文 |
| 简体中文（中國大陸、新加坡） | 簡體中文 |
| 繁體中文（台灣、香港、澳門） | 繁體中文 |
| 列表中沒有任何支援的語言 | 英文 |

語言設為香港或澳門的繁體中文使用者，提示中的 macOS 設定名稱會使用香港用語（私隱與保安・輸入監察）。

介面文字不是 `.lproj` 資源，而是在原始碼的 `L()` 呼叫中把 5 種語言並排寫在一起。
新增的文字只要缺少任何一種語言，**建置就會失敗**，所以不會漏翻。

## 系統需求

- **macOS 12（Monterey）或以上版本**
  — 可在  選單 → **關於這台Mac** 中查看
- **Intel 與 Apple 晶片**
  — 一個通用二進位檔同時包含兩種架構，不需要依 Mac 分別下載
- 「輔助使用」權限
- 「輸入監控」（香港：輸入監察）權限 — 攔截按鍵輸入需要它，與「輔助使用」**分開**授權

> 以上是在發布版本上核實的值：最低版本 `12.0`，兩個切片的架構都是 `x86_64 arm64`。
> 另外，**開發與測試都在 macOS 27 上完成，12 到 26 的實機尚未驗證。**

## 授權

[MIT](LICENSE)

清潔畫面使用的字型皆遵循 SIL Open Font License 1.1。App 中只包含畫面上會出現的字元的子集。來源與重新產生的方法見 [`assets/fonts/README.md`](assets/fonts/README.md#english)。

- 韓文・英文 — Gowun Dodum（고운돋움，© 2021 The Gowun Dodum Project Authors）— [`OFL-GowunDodum.txt`](assets/fonts/OFL-GowunDodum.txt)
- 日文 — Klee One（© 2020 The Klee Project Authors）— [`OFL-KleeOne.txt`](assets/fonts/OFL-KleeOne.txt)
- 簡體中文 — 以霞鹜文楷（LXGW WenKai，© 2021-2026 LXGW）為基礎的子集。由於原字型宣告了保留字型名稱，在 App 中使用「Ddaka Kai SC」這個名稱 — [`OFL-LXGWWenKai.txt`](assets/fonts/OFL-LXGWWenKai.txt)
- 繁體中文 — 霞鶩文楷 TC（LXGW WenKai TC，© 2024 The LXGW WenKai Project Authors）— [`OFL-LXGWWenKaiTC.txt`](assets/fonts/OFL-LXGWWenKaiTC.txt)
