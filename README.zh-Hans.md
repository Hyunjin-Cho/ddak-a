<p align="center">
  <img src="assets/icon/AppIcon-256.png" width="128" alt="ddak-a 应用图标">
</p>

# ddak-a（닦아）

[한국어](README.md#korean) · [English](README.md#english) · [日本語](README.ja.md) · **简体中文** · [繁體中文](README.zh-Hant.md)

> **基准日期：** 2026-11-18
> **状态：** **v1.3 已发布** — 可在 [Releases](https://github.com/Hyunjin-Cho/ddak-a/releases) 下载（应用和 DMG 均已通过 Apple 公证）

<!-- 2026-11-18 (#27): README.md(한국어·영어)의 중국어 간체판. README.md 를 고치면 이 파일도 같이 고친다.
     상태 줄 규칙은 README.md 맨 위 주석과 같다(새 버전 동작을 적는 문장과 상태 줄은 같이 움직인다).
     메뉴·설정 이름(快捷指令 · 打开App · 快捷指令详细信息 · 添加键盘快捷键 · 无障碍快捷键 · 关于本机 ·
     无障碍 · 输入监控)은 macOS 27.0 · 단축어 10.0 의 시스템 문자열 표에서 확인했다.
     无障碍 은 macOS 27 에서 바뀐 이름이고 26 이하는 辅助功能 이다(애플 간체 도움말 mh43185 버전별 대조 · #29) → 처음 나오는 곳과 요구 사항에 둘 다 적는다.
     앱 문구(要启动 ddak-a 吗？ · 开始 · 完成)는 Sources/ddaka/main.swift 의 간체 그대로. -->

这是一款 macOS 实用工具：运行期间会**完全屏蔽整个键盘**，这样在擦拭 Mac 键盘时即使不小心按到按键，
输入也不会传到电脑上。**鼠标和触控板照常可用。**

名字 닦아（*ddak-a*）在韩语里是"擦一擦"的意思。

<p align="center">
  <b>macOS 12（Monterey）或更高版本</b> · <b>同时支持 Intel 与 Apple 芯片</b>
</p>

<p align="center">
  <img src="assets/screenshot.jpg" width="680" alt="ddak-a 运行时的画面">
  <br>
  <sub>运行时的画面（v1.3）— 每次启动都会从 10 幅插画中选一幅，覆盖已连接的<b>所有显示器</b></sub>
</p>

<table align="center">
  <tr>
    <td align="center"><img src="assets/readme/themes/sunset.jpg" width="136" alt="晚霞"><br><sub>晚霞</sub></td>
    <td align="center"><img src="assets/readme/themes/beach.jpg" width="136" alt="海边"><br><sub>海边</sub></td>
    <td align="center"><img src="assets/readme/themes/busstop.jpg" width="136" alt="公交车站"><br><sub>公交车站</sub></td>
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

## 安装

1. 从 [Releases](https://github.com/Hyunjin-Cho/ddak-a/releases) 下载 `.dmg`
2. 在打开的窗口中，**把 `닦아` 拖到 `Applications` 文件夹**
3. 从"应用程序"文件夹启动

> ### ⚠️ 运行前请先移到"应用程序"文件夹
>
> 从网上下载的应用如果在"应用程序"文件夹**之外**运行，macOS 每次都会从一个新的临时副本启动它（App Translocation）。
> **从这个临时位置运行的应用，无法保留"无障碍"和"输入监控"权限** — 即使打开了，下次启动时又会变回关闭。
>
> **自己动手**把它移到"应用程序"文件夹，就能解除这种状态。如果一直放在"下载"或桌面上，权限无论开多少次都留不住。
>
> 从 v1.1 起，应用会自己发现这种情况，**在请求任何权限之前**提示你，然后退出。

首次启动时会请求**无障碍**（macOS 26 及更早版本中称为"辅助功能"）和**输入监控**权限。屏蔽键盘需要这两项。

## 工作方式

1. 启动 → 弹出"要启动 ddak-a 吗？"确认
2. 检查权限 — **无障碍** + **输入监控**（缺少时应用会自己请求）
3. 用全屏插画覆盖已连接的**所有显示器**并开始倒计时 — 每次启动都会从 10 个场景中随机选一个（v1.3）
4. 以下任一情况先发生即结束
   - 点击 **"完成"** 按钮 → 立即退出
   - 3 分钟倒计时结束 → 自动退出
   - **Cmd + Shift + 9（⌘⇧9）** → 应用自己检测到后立即退出

## 用一个快捷键启动和退出（可选）

给 macOS 自带的**快捷指令** App 设置一个键盘快捷键，就能不点图标直接启动 ddak-a。
把这个键设为 **⌘⇧9**，启动键和退出键就是同一个 — **只要记住 ⌘⇧9 就够了。**

1. 在**快捷指令**中点击 **＋**，新建一个快捷指令
2. 添加 **打开App** 操作，App 选择 **닦아**
3. **快捷指令详细信息**（ⓘ）→ **添加键盘快捷键** → 按下 **⌘⇧9**

这样一来：**⌘⇧9** → 确认窗口中点 **开始** → 开始清洁；清洁中按 **⌘⇧9** → 退出。

- 清洁中按下的 ⌘⇧9 会先被 ddak-a 收到，所以快捷指令不会再次启动 ddak-a
  （已在 macOS 27.0・快捷指令 10.0 上通过运行日志确认。快捷指令 App 从 macOS 12 起就有，但更早的版本未经确认）
- 用其他键也可以启动，但**退出键始终是 ⌘⇧9**

> 💡 这个方法由韩国 Naver 社区 [맥쓰사（用 Mac 的人们）](https://cafe.naver.com/inmacbook) 的 **봄물결（Bommulgyeol）** 提出，谢谢！

## 屏蔽范围

| 输入 | 是否屏蔽 |
|---|---|
| 内建键盘 | 屏蔽 |
| 蓝牙 / USB 外接键盘 | 屏蔽 |
| 媒体键（亮度、音量等） | 屏蔽 |
| 触控 ID 键 | **会通过 — 由 macOS 处理，属于正常行为。** 按一下会锁定屏幕，快速连按三下会打开无障碍（辅助功能）快捷键面板。解锁后清洁画面会继续 |
| 🌐（fn）键 | **会通过** — 清洁画面没有输入框，按下也不会发生任何事 |
| Cmd + Shift + 9（⌘⇧9） | 由应用接收并**立即退出**（不会传给其他应用） |
| 鼠标 / 触控板 | 不屏蔽 |

## 安全保障

对一个屏蔽键盘的应用来说，最危险的故障是"一直不放开"。所以这里叠加了多层彼此独立的机制。

- 3 分钟倒计时结束后正常退出
- 一个**独立于倒计时运行**的安全计时器会在 190 秒时再次尝试退出
- 万一连这个计时器也失败，**与应用主逻辑无关的后台看门狗**会数到 195 秒并结束进程。进程不在了，键盘屏蔽也就解除了
- 退出按钮显示在**每一台显示器**上，鼠标在哪里都能点到
- 布局会按比例缩小，在小屏幕上退出按钮也不会被裁掉
- **不会同时运行两个。** 如果有两个屏蔽程序在运行，退出快捷键只能关掉其中一个，另一个会继续屏蔽。
  已在 macOS 27 上确认，更早的版本未经确认 — 即使没能阻止，上面的各项自动解除也会在每个实例上分别生效

## 遇到问题时（日志）

从 v1.2 起，ddak-a 会把**每次清洁是怎么结束的**写入 macOS 日志。如果键盘解除得晚了，或者看起来不对劲，
请在终端中运行下面的命令，并把输出附在 [Issue](https://github.com/Hyunjin-Cho/ddak-a/issues) 里。

```bash
/usr/bin/log show --last 1h --predicate 'subsystem == "com.vismotive.ddaka"'
```

- `reason=` 后面的词就是结束原因 — `done-button`（完成按钮）· `countdown`（3 分钟）· `shortcut`（⌘⇧9）·
  `safety-timer`（190 秒安全计时器）· `screens-gone`（所有显示器都消失了）
- 如果 195 秒强制结束生效，会看到 `hard kill`
- 从 v1.3 起，开始的那一行还会带上 `theme=`（显示了哪幅插画）和 `art=`（是否加载成功 — `false` 表示退回了纯天蓝色背景）
- 🔒 **绝不记录按键内容。** 只记录应用自己做了什么 — 开始和结束、结束原因、权限状态

## 自行构建

如何自行构建、如何制作经过公证的发布版本，以及项目结构，请见 [`docs/BUILDING.md`](docs/BUILDING.md#english)（韩语・英语）。

## 显示语言

应用会自动跟随 Mac 的系统语言，应用内没有语言设置。

准确地说，它会使用系统"首选语言"列表中**本应用支持的、排在最前面的语言**。
如果第一项是不支持的语言（比如法语），第二项是简体中文，就会显示简体中文。

| 系统语言 | 显示为 |
|---|---|
| 한국어 | 韩语 |
| English | 英语 |
| 日本語 | 日语 |
| 简体中文（中国大陆、新加坡） | 简体中文 |
| 繁體中文（台湾、香港、澳门） | 繁体中文 |
| 列表中没有任何支持的语言 | 英语 |

界面文字不是 `.lproj` 资源，而是在源代码的 `L()` 调用中把 5 种语言并排写在一起。
新增的文字只要缺少任何一种语言，**构建就会失败**，所以不会漏翻。

## 系统要求

- **macOS 12（Monterey）或更高版本**
  — 可在  菜单 → **关于本机** 中查看
- **Intel 与 Apple 芯片**
  — 一个通用二进制文件同时包含两种架构，不需要按 Mac 分别下载
- "无障碍"权限（macOS 26 及更早版本中称为"辅助功能"）
- "输入监控"权限 — 拦截按键输入需要它，与"无障碍"**分开**授权

> 以上是在发布版本上核实的值：最低版本 `12.0`，两个切片的架构都是 `x86_64 arm64`。
> 另外，**开发和测试都在 macOS 27 上完成，12 到 26 的实机尚未验证。**

## 许可

[MIT](LICENSE)

清洁画面使用的字体均遵循 SIL Open Font License 1.1。应用中只包含画面上会出现的字符的子集。来源和重新生成方法见 [`assets/fonts/README.md`](assets/fonts/README.md#english)。

- 韩语・英语 — Gowun Dodum（고운돋움，© 2021 The Gowun Dodum Project Authors）— [`OFL-GowunDodum.txt`](assets/fonts/OFL-GowunDodum.txt)
- 日语 — Klee One（© 2020 The Klee Project Authors）— [`OFL-KleeOne.txt`](assets/fonts/OFL-KleeOne.txt)
- 简体中文 — 基于霞鹜文楷（LXGW WenKai，© 2021-2026 LXGW）的子集。由于原字体声明了保留字体名称，在应用中使用"Ddaka Kai SC"这一名称 — [`OFL-LXGWWenKai.txt`](assets/fonts/OFL-LXGWWenKai.txt)
- 繁体中文 — 霞鶩文楷 TC（LXGW WenKai TC，© 2024 The LXGW WenKai Project Authors）— [`OFL-LXGWWenKaiTC.txt`](assets/fonts/OFL-LXGWWenKaiTC.txt)
