# Suno BGM 提示词

在 Suno 里用 **Instrumental** 模式生成，时长选 60 秒左右。

## Prompt

```
Instrumental background music for a 50-second product intro video. Warm, minimal soft ambient / lo-fi electronica. 70 BPM. Gentle Rhodes chords, soft pad, subtle vinyl texture, no vocals, no strong drums. Calm and optimistic, slightly curious. Steady, gentle build, natural fade-out at the end. 60 seconds.
```

## Style tags（可选）

```
warm ambient, lo-fi, soft rhodes, minimal, calm, no drums, instrumental
```

## 交付

- 下载 MP3 或 WAV，放到 `video/assets/bgm/`
- 文件名建议：`suno-take1.mp3`
- 我会在 `build.sh` 里把 BGM 压到人声下（约 -22 dB）并做淡入淡出；如果曲子有前奏空白，我会从 2–4 秒处截取
