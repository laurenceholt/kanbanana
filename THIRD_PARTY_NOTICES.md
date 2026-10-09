# Third-party and asset notices

## Software

kanbanana's Swift/Python source is MIT licensed (LICENSE). It uses Apple's system frameworks. No Swift Package Manager dependencies are declared.

The distributable app embeds CPython 3.12.14 from Astral's python-build-standalone release 20260901. The build pins the archive's SHA-256 in `scripts/fetch-runtime.zsh`. CPython uses the Python Software Foundation license; the app includes the complete upstream component notice set in `Contents/Resources/PythonLicenses/`, plus the notices retained inside the Python runtime. Preserve those notices when redistributing. See [python-build-standalone](https://github.com/astral-sh/python-build-standalone) for build provenance and [Python's license](https://docs.python.org/3/license.html).

Gitleaks is an MIT-licensed development/release-audit tool, not bundled with the app. Its version and checksum are pinned in `scripts/audit.zsh`.

## Artwork

`Resources/Branding/banana.png` is AI-generated pop-art-inspired artwork, offered with this project's MIT license. Its generation prompt is recorded beside the asset. It is not an official mark or endorsement of another artist, album or company.

The 42 art backgrounds are images obtained from Wikimedia Commons, with individual file records identifying public-domain, CC0, CC BY or CC BY-SA terms. They cover works from prehistory to 1998. **They are not all CC0 and are not covered by the source-code MIT license.**

Downloaded JPEG/PNG files are bundled unchanged. The app displays cropped, zoomed versions with a contrast overlay. CC BY-SA images and their adapted display versions retain the indicated CC BY-SA license. Photographer attributions, image-license links, artwork/museum links, download URLs, SHA-256 hashes, crop parameters and source rights metadata are retained in `Resources/Art/catalog.json` and the per-file table in `Resources/Art/README.md`. These files ship inside the app. The art picker exposes photographer credits and a link to each image's licensing page.

The attribution-required photographs are:

- `willendorf.jpg`: MatthiasKabel, **CC BY 2.5**.
- `nefertiti.jpg`: Philip Pikart, **CC BY-SA 3.0**.
- `single-form.jpg`: QuentinUK, **CC BY-SA 3.0** (Barbara Hepworth's permanent public sculpture in Battersea Park, London).
- `guggenheim.jpg`: Naotake Murayama, **CC BY 2.0** (Frank Gehry's Guggenheim Museum Bilbao, Spain).
- `angel.jpg`: saw2th, **CC BY-SA 2.0** (Antony Gormley's permanent public sculpture in Gateshead, England).

Lascaux's reproduction additionally credits Commons contributor EU, and the historical photograph of Duchamp's *Fountain* credits Alfred Stieglitz. Image licenses do not transfer copyright in depicted modern artworks. The UK sculpture photographs depict permanent works in public places (see [Copyright, Designs and Patents Act, section 62](https://www.legislation.gov.uk/ukpga/1988/48/section/62)). No artist, museum or Wikimedia endorsement is implied.

Claude and Codex icons are read from the user's installed applications at runtime; their artwork is not bundled. Product names and marks belong to their respective owners. kanbanana is not affiliated with Anthropic or OpenAI.
