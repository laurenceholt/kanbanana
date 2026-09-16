#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build docs
sources=(Sources/AgentKanban/*.swift)
sources=(${sources:#Sources/AgentKanban/App.swift})
swiftc -parse-as-library "${sources[@]}" scripts/render-preview.swift -o .build/render-preview
KANBAN_PREVIEW_MODE=focus KANBAN_PREVIEW_THEME=photos KANBAN_PREVIEW_PHOTO=puppy .build/render-preview docs/focus-beta.png
KANBAN_PREVIEW_MODE=lanes KANBAN_PREVIEW_THEME=classic KANBAN_PREVIEW_BACKGROUND=butter .build/render-preview docs/projects-beta.png
