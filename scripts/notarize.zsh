#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
: ${KANBAN_SIGN_IDENTITY:?Set your Developer ID Application identity}
: ${KANBAN_NOTARY_PROFILE:?Set your notarytool Keychain profile name}
[[ $KANBAN_SIGN_IDENTITY == "Developer ID Application: "* ]] || { print -u2 'Use a Developer ID Application identity, not Apple Development or ad-hoc signing.'; exit 1; }
zsh scripts/build.zsh
release_stage=$(mktemp -d "${TMPDIR:-/tmp}/kanbanana-release.XXXXXX")
trap 'rm -rf "$release_stage"' EXIT
ditto --norsrc --noextattr dist/kanbanana.app "$release_stage/kanbanana.app"
xattr -cr "$release_stage/kanbanana.app"
codesign --verify --deep --strict "$release_stage/kanbanana.app"
ditto -c -k --keepParent "$release_stage/kanbanana.app" "$release_stage/submission.zip"
xcrun notarytool submit "$release_stage/submission.zip" --keychain-profile "$KANBAN_NOTARY_PROFILE" --wait
xcrun stapler staple "$release_stage/kanbanana.app"
xcrun stapler validate "$release_stage/kanbanana.app"
spctl --assess --type execute --verbose "$release_stage/kanbanana.app"
release_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$release_stage/kanbanana.app/Contents/Info.plist")
[[ $release_version =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$' ]] || { print -u2 'Invalid app release version'; exit 1; }
archive_name="kanbanana-${release_version}-arm64.zip"
image_name="kanbanana-${release_version}-arm64.dmg"
ditto -c -k --keepParent "$release_stage/kanbanana.app" "$release_stage/$archive_name"

# The disk image contains the already-stapled app, so either download works offline.
mkdir "$release_stage/image"
ditto --norsrc --noextattr "$release_stage/kanbanana.app" "$release_stage/image/kanbanana.app"
ln -s /Applications "$release_stage/image/Applications"
hdiutil create -volname kanbanana -srcfolder "$release_stage/image" -format UDZO -fs HFS+ "$release_stage/$image_name"
codesign --sign "$KANBAN_SIGN_IDENTITY" --timestamp "$release_stage/$image_name"
xcrun notarytool submit "$release_stage/$image_name" --keychain-profile "$KANBAN_NOTARY_PROFILE" --wait
xcrun stapler staple "$release_stage/$image_name"
xcrun stapler validate "$release_stage/$image_name"
spctl --assess --type open --context context:primary-signature --verbose "$release_stage/$image_name"

# Publish output only after both formats pass Apple's checks.
cp "$release_stage/$archive_name" "$release_stage/$image_name" dist/
(cd dist && shasum -a 256 "$archive_name" "$image_name" > SHA256SUMS)
print 'Notarized ZIP and disk image ready in dist/'
