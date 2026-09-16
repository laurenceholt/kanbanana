#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
: ${KANBAN_SIGN_IDENTITY:?Set your Developer ID Application identity}
: ${KANBAN_NOTARY_PROFILE:?Set your notarytool Keychain profile name}
[[ $KANBAN_SIGN_IDENTITY != - ]] || { print -u2 'A Developer ID certificate is required.'; exit 1; }
zsh scripts/build.zsh
release_stage=$(mktemp -d "${TMPDIR:-/tmp}/kanbanana-release.XXXXXX")
trap 'rm -rf "$release_stage"' EXIT
ditto --norsrc --noextattr dist/kanbanana.app "$release_stage/kanbanana.app"
xattr -cr "$release_stage/kanbanana.app"
ditto -c -k --keepParent "$release_stage/kanbanana.app" "$release_stage/submission.zip"
xcrun notarytool submit "$release_stage/submission.zip" --keychain-profile "$KANBAN_NOTARY_PROFILE" --wait
xcrun stapler staple "$release_stage/kanbanana.app"
xcrun stapler validate "$release_stage/kanbanana.app"
spctl --assess --type execute --verbose "$release_stage/kanbanana.app"
ditto -c -k --keepParent "$release_stage/kanbanana.app" dist/kanbanana-0.2.0-beta.1-arm64.zip
shasum -a 256 dist/kanbanana-0.2.0-beta.1-arm64.zip > dist/SHA256SUMS
print 'Notarized archive ready in dist/'
