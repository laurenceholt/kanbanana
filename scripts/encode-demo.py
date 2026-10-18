"""Encode rendered synthetic scenes; never capture a screen or read user stores."""
import json
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
frames = root / ".build/demo"
output = root / "docs/media"
scenes = json.loads((frames / "scenes.json").read_text())
transition = 0.25
inputs = []
filters = []
for i, scene in enumerate(scenes):
    inputs += ["-loop", "1", "-framerate", "30", "-t", str(scene["duration"]), "-i", str(frames / (scene["id"] + ".png"))]
    filters.append(f"[{i}:v]scale=1920:1080:flags=lanczos,setsar=1,format=yuv420p,settb=AVTB[v{i}]")
elapsed = scenes[0]["duration"]
previous = "v0"
for i in range(1, len(scenes)):
    name = f"fade{i}"
    filters.append(f"[{previous}][v{i}]xfade=transition=fade:duration={transition}:offset={elapsed-transition}[{name}]")
    previous = name
    elapsed += scenes[i]["duration"] - transition
subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y", "-filter_complex_threads", "2", *inputs,
                "-filter_complex", ";".join(filters), "-map", f"[{previous}]", "-an", "-c:v", "libx264",
                "-preset", "medium", "-crf", "20", "-r", "30", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                str(output / "kanbanana-demo.mp4")], check=True)
shutil.copy2(frames / "01-focus.png", output / "demo-poster.png")
# The captions are burned into the video; WebVTT and a plain transcript are also provided.
def stamp(seconds):
    millis = round(seconds * 1000)
    return f"{millis//3600000:02}:{millis//60000%60:02}:{millis//1000%60:02}.{millis%1000:03}"
vtt = ["WEBVTT", ""]
start = 0.0
for i, scene in enumerate(scenes):
    end = start + scene["duration"] - (transition if i < len(scenes)-1 else 0)
    vtt += [f"{stamp(start)} --> {stamp(end)}", scene["caption"], ""]
    start = end
(output / "kanbanana-demo.vtt").write_text("\n".join(vtt), encoding="utf-8")
probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(output / "kanbanana-demo.mp4")]))
video = next(s for s in probe["streams"] if s["codec_type"] == "video")
assert video["codec_name"] == "h264" and video["width"] == 1920 and video["height"] == 1080
assert abs(float(probe["format"]["duration"]) - elapsed) < 0.2
assert all(s["codec_type"] != "audio" for s in probe["streams"])
print(f"Verified {elapsed:.2f}s H.264, 1920×1080, 30fps, silent; {Path(output / 'kanbanana-demo.mp4').stat().st_size / 1e6:.1f} MB")
