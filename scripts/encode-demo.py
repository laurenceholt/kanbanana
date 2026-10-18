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
walkthrough_duration = captions[-1]['end']
ending_duration = 4
duration = walkthrough_duration + ending_duration
music = output / 'electronica.m4a'
# Reuse an earlier musical phrase so the generated track's original ending cannot fade too soon.
# A two-second equal-power crossfade joins the phrase; the only final fade is at the video's end.
music_mix = frames / 'extended-music.wav'
subprocess.run([
    'ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y', '-i', str(music),
    '-filter_complex',
    f'[0:a]asplit=2[a][b];[a]atrim=end={walkthrough_duration-8},asetpts=PTS-STARTPTS[body];'
    '[b]atrim=start=20:end=34,asetpts=PTS-STARTPTS[tail];'
    '[body][tail]acrossfade=d=2:c1=qsin:c2=qsin[music]',
    '-map', '[music]', '-c:a', 'pcm_s16le', str(music_mix)
], check=True)
subprocess.run(['swift', str(root / 'scripts/render-demo-ending.swift'), str(frames / 'ending-overlay.png')], check=True)
# Two-pass normalization gives the background a deliberately quiet, repeatable level.
measurement = subprocess.run([
    'ffmpeg', '-hide_banner', '-i', str(music_mix), '-t', str(duration),
    '-af', 'loudnorm=I=-28:TP=-6:LRA=7:print_format=json', '-f', 'null', '-'
], capture_output=True, text=True, check=True).stderr
stats = json.loads(re.search(r'\{\s*"input_i".*?\}', measurement, re.S).group())
normalize = (f"loudnorm=I=-28:TP=-6:LRA=7:measured_I={stats['input_i']}:"
             f"measured_TP={stats['input_tp']}:measured_LRA={stats['input_lra']}:"
             f"measured_thresh={stats['input_thresh']}:offset={stats['target_offset']}:linear=true")
subprocess.run([
    'ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y',
    '-i', str(frames / 'walkthrough-silent.mp4'), '-i', str(music_mix),
    '-loop', '1', '-framerate', '30', '-i', str(frames / 'ending-overlay.png'),
    '-filter_complex',
    f'[0:v]tpad=stop_mode=clone:stop_duration={ending_duration},'
    f'drawbox=x=0:y=1690:w=iw:h=230:color=black:t=fill:enable=gte(t\\,{walkthrough_duration})[app];'
    f'[2:v]scale=1080:1920:flags=lanczos,format=rgba,fade=t=in:st={walkthrough_duration}:d=0.6:alpha=1[url];'
    '[app][url]overlay=0:0:format=auto[video]',
    '-map', '[video]', '-map', '1:a:0', '-t', str(duration),
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p',
    '-af', normalize + f',afade=t=in:d=1.2,afade=t=out:st={duration-1.2}:d=1.2',
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
vtt += [f'{stamp(walkthrough_duration)} --> {stamp(duration)}', 'github.com/laurenceholt/kanbanana', '']
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
print(f'Verified {duration}s app walkthrough with URL ending, portrait 1080×1920, 30fps, H.264/AAC, quiet electronica.')
