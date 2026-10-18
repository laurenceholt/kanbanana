# Continuous app walkthrough

[Watch/download the MP4](media/kanbanana-demo.mp4) · [Subtitles](media/kanbanana-demo.vtt) · [Poster](media/demo-poster.png)

The video is **52 seconds, portrait 1080×1920, 30 fps, H.264/AAC**. It stays in Night mode, starts in Focus and ends in the full Projects view. The app fills the frame, with conversational subtitles below it and quiet instrumental electronica. There are no slides, scene cuts, voiceover or theme changes.

## Feature order and interaction script

| Time | Continuous interaction | Subtitle |
| --- | --- | --- |
| 0–4 s | Hold on Focus | This is kanbanana. I keep it beside whatever I’m working on. |
| 4–8 s | Show cards from both providers | It brings my Claude Code and Codex desktop work into one little window. |
| 8–12 s | Point across Running, Needs me and Ready to check counts | Up here: what’s running, what needs me, and what’s ready to check. |
| 12–16 s | Scroll down through Ready to check | I can scroll through the replies without losing track of things. |
| 16–20 s | Pause on reports, then scroll back up | Each card gives me a short version of what the agent reported. |
| 20–24 s | Point at the first conversation title | Click a conversation to open it in Claude or Codex. |
| 24–28 s | Click the release-notes star; watch it move to the top | If something matters most, I star it. It stays at the top. |
| 28–32 s | Click that card’s Dealt with button | Once I’ve looked at it, I click here to mark it Dealt with. |
| 32–36 s | Show its removal and the changed counts | It leaves this list. A new request will bring it back. |
| 36–40 s | Click the expand arrows and widen the same window | And when I want the bigger picture, I expand to Projects. |
| 40–46 s | Hold on project lanes, retaining the changed card state | The conversations stay separate, but now they’re grouped by project. |
| 46–52 s | Point at a project’s goal note; end on Projects | These little notes remind me what I’m trying to get done. |

Native conversation navigation is explained but not executed: the fictional cards have no real destination. The film does not fabricate a Claude or Codex conversation. Likewise, new-request reactivation is described but not demonstrated.

## What “continuous” means here

One persistent `BoardView`, `BoardStore` and native window run for the entire sequence. The recorder dispatches mouse down/up events to the real star, Dealt with and Projects controls. It scrolls the actual native scroll view, then smoothly resizes the same window. Checks fail if the UI clicks do not change priority order, reduce Ready to check from six cards to five, or select Projects.

Every frame comes from that view. The pointer/click rings and subtitles are composited onto those frames. The window is hosted offscreen, so the recorder cannot pick up the desktop, other windows or the live board. This is a continuous scripted interaction with the app, not a recording of live provider execution or a performance benchmark. Rendering may take longer than the 52-second output on a busy machine.

## Fictional data and privacy

`DemoData` supplies Pocket weather, Trail guide and Launch notes. All conversations and reports are invented. Summaries are prewritten examples; recording makes no API calls. Monitoring is disabled, credentials throw if accessed, and the board/preferences live in unique temporary storage that is removed afterwards. The installed app and its data are untouched.

Provider icons can be resolved from installed apps, as in kanbanana itself; otherwise its normal fallback is used. The window uses Night throughout, with no third-party background artwork.

## Desktop and command-line scope

The video deliberately says “desktop work”, not “all sessions”. Standalone Claude Code terminal sessions are not discovered without Desktop metadata. Local Codex CLI records can be included by the reader, but clicking still opens Codex Desktop; a terminal-only workflow has not been validated end to end. Cloud-backed Codex history is also outside the current reader. See [compatibility](COMPATIBILITY.md).

## Reproduce

Requirements: Apple Silicon Mac, Swift 6, a logged-in graphical macOS session, and FFmpeg/FFprobe on PATH. If you already use Homebrew, `brew install ffmpeg` supplies both. No third-party Python packages or generation credentials are needed to reuse the bundled soundtrack.

```zsh
zsh scripts/demo.zsh
```

`scripts/render-demo.swift` records the persistent app view to `.build/walkthrough/walkthrough-silent.mp4`, writes subtitles to `captions.json`, and saves inspection frames. `scripts/encode-demo.py` adds the bundled soundtrack, normalizes it to a quiet −28 LUFS target, adds opening/closing audio fades, and verifies the complete encoded file. Outputs in `docs/media/` are overwritten:

- `kanbanana-demo.mp4`: phone-oriented video with web fast-start.
- `kanbanana-demo.vtt`: subtitles with matching timing.
- `demo-poster.png`: opening frame.

Edit the timeline, pointer coordinates and subtitles in the Swift renderer. Coordinates deliberately match the current real UI; recheck them after UI changes. Do not replace failed clicks with direct state mutations. The renderer checks that the actions worked. The app sources are unchanged by this recording setup.

Before posting, play the final file with sound and check the pacing and phone legibility. No download claim should precede a tested public artifact. Posting to X remains a separate, maintainer-approved action.

## Soundtrack and rights

[Media notes](media/README.md) include the music provenance and applicable rights. This walkthrough replaces the earlier landscape slide-style demo; that older version's artwork attribution/license remains applicable to copies from older commits.
