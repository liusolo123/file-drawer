# 文件抽屉介绍片 · 制作计划

状态：已确认，先做 15 秒样片。

## 规格

| 项 | 值 |
| --- | --- |
| 时长 / 画幅 | 成片约 50 秒；样片约 15–17 秒 |
| 分辨率 / 帧率 | 1920×1080，30fps |
| 语言 | 中文普通话，第一人称 |
| 画面 | 暖白 + 石墨 + 雾蓝；HTML/CSS 代码渲染为主，真实截图嵌入设备框 |
| 配音 | Apple TTS；样片默认 Tingting，试听后确定 |
| BGM | Suno 生成无唱词氛围乐；样片用代码占位 |
| 字幕 | 硬字幕 + `.srt` |
| 结尾 | 指向 GitHub 仓库 |

## 五段时间轴（成片）

| 时间 | 段落 | 内容 |
| --- | --- | --- |
| 0–8s | 痛点 | Finder 反复切换、工作中断 |
| 8–18s | 定位 + 唤出 | 菜单栏图标、悬停刘海、快捷键 ⌃⌥F |
| 18–34s | 核心演示 | 搜索、拖出到浏览器/聊天、多选 |
| 34–44s | 亮点 | 不抢焦点、自动收起、常驻菜单栏 |
| 44–50s | 结尾 | 封面定格 + GitHub 仓库 |

## 流水线

1. 旁白稿与分镜（`script.md`）
2. TTS 试听 → 选定音色 → 分段生成
3. 真实截图收集（`assets/screenshots/`，2–3 张）
4. HTML/CSS 场景 + Playwright 逐帧（`src/scene.html`、`src/render.mjs`）
5. 音频：旁白 + BGM 混音
6. ffmpeg 合成 + 硬字幕
7. 封面导出
8. GitHub 发布（README + `release/` 内的 DMG）

## 目录

```
video/
├── PLAN.md
├── script.md
├── src/            scene.html, render.mjs
├── assets/
│   ├── screenshots/
│   ├── audio/      auditions/ 与分段旁白
│   └── bgm/
├── frames/         逐帧 PNG（不入库）
├── out/            样片与成片
└── build.sh
```

## 截图规范

- 2–3 张：抽屉全景、搜索结果、拖出瞬间
- 浅色模式；窗口约 720×440；Retina 截图（2x）最佳
- 用临时演示文件夹（工作 / 设计 / 灵感），不要出现真实项目名
- 放到 `video/assets/screenshots/`

## Suno 提示词（BGM）

> Instrumental background music for a 50-second product intro video. Warm, minimal soft ambient / lo-fi electronica. 70 BPM. Gentle Rhodes chords, soft pad, subtle vinyl texture, no vocals, no strong drums. Calm and optimistic, slightly curious. Steady, gentle build, natural fade-out at the end. 60 seconds.

生成后放到 `video/assets/bgm/`。

## 风险

- Apple TTS 机械 → 切 edge-tts
- Suno 曲长不合适 → 截取中段并淡出
- 真实截图与代码 UI 冲突 → 统一设备框、背景、阴影
- 逐帧渲染慢 → 1500 帧约 2–5 分钟
