# Demo video

[Watch/download the MP4](media/kanbanana-demo.mp4) · [Captions](media/kanbanana-demo.vtt) · [Poster](media/demo-poster.png)

The current video is **32.75 seconds, 1920×1080, 30 fps, H.264, silent**, with all explanation visible on screen. It describes a source beta; do not use its “download coming soon” end-card after publishing a downloadable release without updating it.

## What is shown

| Approximate time | Workflow |
| --- | --- |
| 0–3 s | Focus: one narrow window for Claude Code and Codex |
| 3–7 s | Read the latest agent report |
| 7–10 s | Star the release-notes card; it moves to the top |
| 10–13 s | Mark that round Dealt with; it leaves Ready to check |
| 13–18 s | Switch to Projects and see conversations grouped in lanes |
| 18–22 s | Focus a project and read its goal note |
| 22–25 s | Retrace three requests in the real history view |
| 25–29 s | Show a To do reminder for the next round |
| 29–33 s | Return to Focus and the repository link |

The scenes are rendered from actual SwiftUI components, with edits executed through the real BoardStore commands. Transitions between shots are editorial crossfades; this is not a continuous screen recording or a measurement of integration speed. The renderer asserts that starring changes the ordering and acknowledgement removes the card from Ready to check. It does not pretend to open a real conversation in either provider.

## Fictional data and privacy

The shared `DemoData` fixture contains three invented projects: Pocket weather, Trail guide and Launch notes. No actual conversations, names, emails, filesystem paths or account details are used. Request/report summaries are prewritten fictional examples; the film makes no API calls.

The renderer uses a unique temporary board directory and preferences suite, `start: false`, disabled credentials and a summary function that throws if called. History paging exits when monitoring is disabled. It renders views offscreen, without recording the desktop, menu bar, other windows or the user's live board. The installed kanbanana app can keep running throughout production.

Provider icons may be resolved from the installed apps, as in kanbanana itself. If they are not installed, the interface uses its normal fallback. Brand images and background artwork are loaded from repository resources.

## Reproduce

Requirements: Apple Silicon Mac, Swift 6 toolchain and FFmpeg/FFprobe on PATH. If you already use Homebrew, `brew install ffmpeg` supplies both. Other FFmpeg distributions also work; no Python packages are required.

```zsh
zsh scripts/demo.zsh
```

This compiles a separate renderer, creates `.build/demo/` frames, and uses the pinned bundled Python runtime to invoke FFmpeg. Outputs are overwritten only in `docs/media/`:

- `kanbanana-demo.mp4`: upload-ready video, with web fast-start enabled.
- `kanbanana-demo.vtt`: accessible captions/transcript.
- `demo-poster.png`: opening frame.

Edit `scripts/render-demo.swift` for the shot sequence, titles and timing; edit `Sources/AgentKanban/DemoData.swift` for the fictional conversations. `scripts/encode-demo.py` handles encoding and checks the codec, dimensions, duration and absence of audio. `scripts/compile-renderer.zsh` shares compilation setup with documentation previews.

After editing, watch the complete encoded video and inspect the UI text at full resolution. Verify the final GitHub URL, supported scope and availability wording. No claim about signed downloads should precede a tested public artifact.

## Rights

See [media/README.md](media/README.md) for the video's license and artwork attribution. Attribution records must travel with redistributed or edited versions. Posting the video or announcement to X is a separate, maintainer-approved action.
