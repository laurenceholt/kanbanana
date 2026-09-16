# Third-party and asset notices

## Software

kanbanana's Swift/Python source is MIT licensed (LICENSE). It uses Apple's system frameworks. No Swift Package Manager dependencies are declared.

The distributable app embeds CPython 3.12.14 from Astral's python-build-standalone release 20260901. The build pins the archive's SHA-256 in `scripts/fetch-runtime.zsh`. CPython uses the Python Software Foundation license; the app includes the complete upstream component notice set in `Contents/Resources/PythonLicenses/`, plus the notices retained inside the Python runtime. Preserve those notices when redistributing. See [python-build-standalone](https://github.com/astral-sh/python-build-standalone) for build provenance and [Python's license](https://docs.python.org/3/license.html).

Gitleaks is an MIT-licensed development/release-audit tool, not bundled with the app. Its version and checksum are pinned in `scripts/audit.zsh`.

## Artwork

`Resources/Branding/banana.png` is AI-generated pop-art-inspired artwork, offered with this project's MIT license. Its generation prompt is recorded beside the asset. It is not an official mark or endorsement of another artist, album or company.

The eighteen photo backgrounds include twelve generated images and six sourced public-domain/CC0 selections. Attribution, source links, jurisdiction-specific copyright descriptions and generation information are in `Resources/Photos/README.md`. Those sourced photographs retain their documented status rather than being relicensed as source code. The app displays their credits.

Claude and Codex icons are read from the user's installed applications at runtime; their artwork is not bundled. Product names and marks belong to their respective owners. kanbanana is not affiliated with Anthropic or OpenAI.
