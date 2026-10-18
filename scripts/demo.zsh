#!/bin/zsh
# Synthetic-only: render real SwiftUI views and encode a continuous Night-mode walkthrough with subtitles and quiet music.
set -euo pipefail
cd "${0:A:h:h}"
command -v ffmpeg >/dev/null || { print -u2 'FFmpeg is required. See docs/DEMO.md.'; exit 1; }
command -v ffprobe >/dev/null || { print -u2 'FFprobe is required. See docs/DEMO.md.'; exit 1; }
zsh scripts/compile-renderer.zsh demo
mkdir -p .build/walkthrough docs/media
.build/render-demo .build/walkthrough
zsh scripts/fetch-runtime.zsh
.build/runtime/python/bin/python3 -I -B scripts/encode-demo.py
