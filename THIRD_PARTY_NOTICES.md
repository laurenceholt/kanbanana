# Third-party and asset notices

## Software

kanbanana's Swift/Python source is MIT licensed (LICENSE). It uses Apple's system frameworks. No Swift Package Manager dependencies are declared.

The distributable app embeds CPython 3.12.14 from Astral's python-build-standalone release 20260901. The build pins the archive's SHA-256 in `scripts/fetch-runtime.zsh`. CPython uses the Python Software Foundation license; the app includes the complete upstream component notice set in `Contents/Resources/PythonLicenses/`, plus the notices retained inside the Python runtime. Preserve those notices when redistributing. See [python-build-standalone](https://github.com/astral-sh/python-build-standalone) for build provenance and [Python's license](https://docs.python.org/3/license.html).

Gitleaks is an MIT-licensed development/release-audit tool, not bundled with the app. Its version and checksum are pinned in `scripts/audit.zsh`.

## Artwork

`Resources/Branding/banana.png` is AI-generated pop-art-inspired artwork, offered with this project's MIT license. Its generation prompt is recorded beside the asset. It is not an official mark or endorsement of another artist, album or company.

The 24 art backgrounds are images of artworks designated public domain by The Metropolitan Museum of Art, supplied through its Open Access program under CC0. The original downloaded JPEGs are bundled unchanged; the app displays curated crops, zooms and a contrast overlay. Full artwork titles, makers, dates, object IDs, credits, original download URLs, SHA-256 hashes and rights evidence are in `Resources/Art/catalog.json`; see `Resources/Art/README.md`. Display labels sometimes describe a detail rather than reproduce the museum's title. Museum artwork is not relicensed as source code. No museum endorsement is implied.

Claude and Codex icons are read from the user's installed applications at runtime; their artwork is not bundled. Product names and marks belong to their respective owners. kanbanana is not affiliated with Anthropic or OpenAI.
