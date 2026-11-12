#!/bin/bash
# 生成样片：时间轴 → 旁白混音 → BGM → 逐帧渲染 → 合成。
set -euo pipefail

cd "$(dirname "$0")"

python3 src/gen_timeline.py
TOTAL="$(python3 -c "import json;print(json.load(open('src/timeline.json'))['total'])")"
echo "总时长：${TOTAL}s"

# 旁白：前导静音 + 分段 + 间隙（concat，避免 amix 在 ffmpeg 9 下挂起）
LEAD="$(python3 -c "import json;print(json.load(open('src/timeline.json'))['lead'])")"
ffmpeg -y -loglevel error \
  -f lavfi -i "anullsrc=r=48000:cl=mono:d=$LEAD" \
  -i assets/audio/seg1.wav \
  -i assets/audio/seg2.wav \
  -i assets/audio/seg3.wav \
  -filter_complex "$(cat src/mix_filter.txt)" \
  -map "[out]" assets/audio/voice.wav

# 占位 BGM：极简和弦垫，正式版替换为 Suno
FADE_OUT="$(python3 -c "print(max(0, $TOTAL - 2))")"
ffmpeg -y -loglevel error \
  -f lavfi -i "sine=frequency=196:duration=$TOTAL" \
  -f lavfi -i "sine=frequency=246.94:duration=$TOTAL" \
  -f lavfi -i "sine=frequency=293.66:duration=$TOTAL" \
  -f lavfi -i "sine=frequency=392:duration=$TOTAL" \
  -f lavfi -i "anoisesrc=color=pink:duration=$TOTAL:amplitude=0.012" \
  -filter_complex "[0:a][1:a][2:a][3:a]amix=inputs=4:normalize=0,tremolo=f=0.12:d=0.25,lowpass=f=1500[ch];[ch][4:a]amix=inputs=2:normalize=0,volume=0.055,afade=t=in:st=0:d=1.2,afade=t=out:st=$FADE_OUT:d=2[out]" \
  -map "[out]" assets/bgm/placeholder.wav

# 人声 + BGM
ffmpeg -y -loglevel error \
  -i assets/audio/voice.wav \
  -i assets/bgm/placeholder.wav \
  -filter_complex "[0:a]loudnorm=I=-16:TP=-1.5:LRA=11[v];[1:a]amix=inputs=1:normalize=0[b];[v][b]amix=inputs=2:duration=first:normalize=0[out]" \
  -map "[out]" assets/audio/mix.wav

# 逐帧渲染（REUSE_FRAMES=1 可跳过）
if [ "${REUSE_FRAMES:-0}" != "1" ]; then
  node src/render.mjs
fi

ffmpeg -y -loglevel error \
  -framerate 30 -i frames/frame_%05d.png \
  -i assets/audio/mix.wav \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -shortest \
  out/sample.mp4

echo "已生成：video/out/sample.mp4"
ffprobe -v error -show_entries format=duration,size -of default=nw=1 out/sample.mp4
