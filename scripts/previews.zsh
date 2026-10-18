#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
zsh scripts/compile-renderer.zsh preview
mkdir -p docs
KANBAN_PREVIEW_MODE=focus KANBAN_PREVIEW_THEME=photos KANBAN_PREVIEW_ART=searching-void .build/render-preview docs/focus-beta.png
KANBAN_PREVIEW_MODE=lanes KANBAN_PREVIEW_THEME=classic KANBAN_PREVIEW_BACKGROUND=butter .build/render-preview docs/projects-beta.png
