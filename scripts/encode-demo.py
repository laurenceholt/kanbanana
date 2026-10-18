"""Finish the continuous app recording with quiet music and accessible captions."""
import json
import re
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
frames = root / '.build/walkthrough'
output = root / 'docs/media'
captions = json.loads((frames / 'captions.json').read_text())
duration = captions[-1]['end']
music = output / 'electronica.m4a'
# Two-pass normalization gives the background a deliberately quiet, repeatable level.
measurement = subprocess.run([
    'ffmpeg', '-hide_banner', '-i', str(music), '-t', str(duration),
    '-af', 'loudnorm=I=-28:TP=-6:LRA=7:print_format=json', '-f', 'null', '-'
], capture_output=True, text=True, check=True).stderr
stats = json.loads(re.search(r'\{\s*"input_i".*?\}', measurement, re.S).group())
normalize = (f"loudnorm=I=-28:TP=-6:LRA=7:measured_I={stats['input_i']}:"
             f"measured_TP={stats['input_tp']}:measured_LRA={stats['input_lra']}:"
             f"measured_thresh={stats['input_thresh']}:offset={stats['target_offset']}:linear=true")
subprocess.run([
    'ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y',
    '-i', str(frames / 'walkthrough-silent.mp4'), '-i', str(music),
    '-map', '0:v:0', '-map', '1:a:0', '-t', str(duration),
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p',
    '-af', normalize + f',afade=t=in:d=1.2,afade=t=out:st={duration-3}:d=3',
    '-c:a', 'aac', '-b:a', '128k', '-ar', '48000', '-movflags', '+faststart',
    str(output / 'kanbanana-demo.mp4')
], check=True)
shutil.copy2(frames / 'check-0.png', output / 'demo-poster.png')
def stamp(seconds):
    millis = round(seconds * 1000)
    return f'{millis//3600000:02}:{millis//60000%60:02}:{millis//1000%60:02}.{millis%1000:03}'
vtt = ['WEBVTT', '']
for caption in captions:
    vtt += [f"{stamp(caption['start'])} --> {stamp(caption['end'])}", caption['caption'], '']
(output / 'kanbanana-demo.vtt').write_text('\n'.join(vtt), encoding='utf-8')
probe = json.loads(subprocess.check_output([
    'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(output / 'kanbanana-demo.mp4')
]))
video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
assert video['codec_name'] == 'h264' and video['width'] == 1080 and video['height'] == 1920
assert video['r_frame_rate'] == '30/1' and audio['codec_name'] == 'aac'
assert abs(float(probe['format']['duration']) - duration) < 0.1
subprocess.run(['ffmpeg', '-v', 'error', '-i', str(output / 'kanbanana-demo.mp4'), '-f', 'null', '-'], check=True)
print(f'Verified {duration}s continuous app walkthrough, portrait 1080×1920, 30fps, H.264/AAC, quiet electronica.')
