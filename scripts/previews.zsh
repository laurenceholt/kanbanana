#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build docs
sources=(Sources/AgentKanban/*.swift)
sources=(${sources:#Sources/AgentKanban/App.swift})
swift build
build_dir=$(swift build --show-bin-path)
# SwiftPM derives package access identity from the checkout directory, not name.
package_identity=$(sed -n '/"-package-name"/{n;s/[", ]//g;p;q;}' "$build_dir/description.json")
swiftc -swift-version 6 -package-name "$package_identity" -parse-as-library -I "$build_dir/Modules" \
    "${sources[@]}" scripts/render-preview.swift \
    "$build_dir"/KanbananaCore.build/*.swift.o "$build_dir"/KanbananaServices.build/*.swift.o \
    -o .build/render-preview
KANBAN_PREVIEW_MODE=focus KANBAN_PREVIEW_THEME=photos KANBAN_PREVIEW_PHOTO=puppy .build/render-preview docs/focus-beta.png
KANBAN_PREVIEW_MODE=lanes KANBAN_PREVIEW_THEME=classic KANBAN_PREVIEW_BACKGROUND=butter .build/render-preview docs/projects-beta.png
