#!/bin/zsh
# Compile isolated documentation renderers against the real app views.
set -euo pipefail
cd "${0:A:h:h}"
renderer=${1:-preview}
[[ $renderer == preview || $renderer == demo ]] || { print -u2 'Use preview or demo'; exit 1; }
mkdir -p .build
swift build
build_dir=$(swift build --show-bin-path)
package_identity=$(sed -n '/"-package-name"/{n;s/[", ]//g;p;q;}' "$build_dir/description.json")
sources=(Sources/AgentKanban/*.swift)
sources=(${sources:#Sources/AgentKanban/App.swift})
swiftc -swift-version 6 -package-name "$package_identity" -parse-as-library -I "$build_dir/Modules" \
    "${sources[@]}" "scripts/render-${renderer}.swift" \
    "$build_dir"/KanbananaCore.build/*.swift.o "$build_dir"/KanbananaServices.build/*.swift.o \
    -o ".build/render-${renderer}"
