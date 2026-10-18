# Third-party and asset notices

## Software

kanbanana's Swift/Python source is MIT licensed (LICENSE). It uses Apple's system frameworks. No Swift Package Manager dependencies are declared.

The distributable app embeds CPython 3.12.14 from Astral's python-build-standalone release 20260901. The build pins the archive's SHA-256 in `scripts/fetch-runtime.zsh`. CPython uses the Python Software Foundation license; the app includes the complete upstream component notice set in `Contents/Resources/PythonLicenses/`, plus the notices retained inside the Python runtime. Preserve those notices when redistributing. See [python-build-standalone](https://github.com/astral-sh/python-build-standalone) for build provenance and [Python's license](https://docs.python.org/3/license.html).

Gitleaks is an MIT-licensed development/release-audit tool, not bundled with the app. Its version and checksum are pinned in `scripts/audit.zsh`.

## Artwork

`Resources/Branding/banana.png` is AI-generated pop-art-inspired artwork, offered with this project's MIT license. Its generation prompt is recorded beside the asset. It is not an official mark or endorsement of another artist, album or company.

The 19 contemporary art backgrounds are obtained from Wikimedia Commons under per-image CC0, CC BY 2.0, CC BY-SA 3.0 or CC BY-SA 4.0 terms. **These images are not covered by the source-code MIT license.**

The collection credits Todd Williamson, José de Martín Simón, Fons Heijnsbroek, Ben Vollers, Peter Klashorst and Marike Bok. Sources document artist uploads, an artist Flickr release reviewed by Commons, or Wikimedia permission tickets. Full source revisions, permission evidence, per-image attribution and license URLs are preserved in [Resources/Art/catalog.json](Resources/Art/catalog.json), with a readable per-file table in [Resources/Art/README.md](Resources/Art/README.md). These records ship inside the app.

Downloaded JPEG/PNG renditions are bundled unchanged. The app displays cropped, zoomed versions with a contrast overlay; CC BY-SA images and their adapted display versions retain the indicated CC BY-SA license. The art picker exposes artist credits and source/license links. No artist or Wikimedia endorsement is implied.

Claude and Codex icons are read from the user's installed applications at runtime; their artwork is not bundled. Product names and marks belong to their respective owners. kanbanana is not affiliated with Anthropic or OpenAI.

## Demo media

The current `docs/media/kanbanana-demo.mp4` is a Night-mode walkthrough with no third-party background art. Its quiet electronica was generated with Sonilo Music through Higgsfield. Provenance, output-rights links and reuse notes are in [docs/media/README.md](docs/media/README.md). Provider marks remain their owners’ property. Demo conversations are fictional.

The earlier landscape demo in older commits contains Todd Williamson’s *Searching the Void* (2016), CC BY-SA 4.0. Copies of that earlier film retain its attribution and ShareAlike terms.
