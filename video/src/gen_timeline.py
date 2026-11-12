#!/usr/bin/env python3
"""根据分段配音时长生成时间轴、SRT 与混音滤镜。"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"

SEGMENTS = [
    {
        "file": "seg1.wav",
        "lines": [
            "每次找文件，都要切到 Finder，翻半天再切回来。",
            "手头的事，就这么断了。",
        ],
    },
    {
        "file": "seg2.wav",
        "lines": [
            "所以我做了文件抽屉：",
            "鼠标移到屏幕顶部，它就在当前应用上方出现。",
        ],
    },
    {
        "file": "seg3.wav",
        "lines": [
            "直接搜名字，结果带着路径，",
            "不用先找对目录。",
        ],
    },
]

LEAD = 0.35
GAP = 0.45
TAIL = 1.0


def duration(path: Path) -> float:
    out = subprocess.check_output([
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=nw=1:nk=1",
        str(path),
    ])
    return float(out.strip())


def srt_time(seconds: float) -> str:
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def main() -> None:
    segments = []
    cues = []
    cursor = LEAD

    for seg in SEGMENTS:
        d = duration(AUDIO / seg["file"])
        start, end = cursor, cursor + d
        segments.append({"file": seg["file"], "start": start, "end": end})

        weights = [max(1, len(line)) for line in seg["lines"]]
        total_w = sum(weights)
        line_cursor = start
        for line, weight in zip(seg["lines"], weights):
            line_d = d * weight / total_w
            cues.append({
                "start": round(line_cursor, 3),
                "end": round(line_cursor + line_d, 3),
                "text": line,
            })
            line_cursor += line_d

        cursor = end + GAP

    total = segments[-1]["end"] + TAIL

    timeline = {
        "total": round(total, 3),
        "lead": LEAD,
        "tail": TAIL,
        "segments": segments,
        "cues": cues,
    }

    (ROOT / "src" / "timeline.json").write_text(
        json.dumps(timeline, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    srt_lines = []
    for i, cue in enumerate(cues, 1):
        srt_lines.append(str(i))
        srt_lines.append(f"{srt_time(cue['start'])} --> {srt_time(cue['end'])}")
        srt_lines.append(cue["text"])
        srt_lines.append("")
    (ROOT / "src" / "subs.srt").write_text("\n".join(srt_lines), encoding="utf-8")

    pads = []
    for i, seg in enumerate(segments, 1):
        pad = GAP if i < len(segments) else TAIL
        pads.append(f"[{i}:a]apad=pad_dur={pad}[a{i}]")

    inputs = "[0:a]" + "".join(f"[a{i}]" for i in range(1, len(segments) + 1))
    mix = ";".join(pads) + f";{inputs}concat=n={len(segments) + 1}:v=0:a=1[out]"
    (ROOT / "src" / "mix_filter.txt").write_text(mix, encoding="utf-8")

    print(f"total={total:.2f}s  segments={len(segments)}  cues={len(cues)}")


if __name__ == "__main__":
    main()
