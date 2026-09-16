#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
[[ $(uname -m) == arm64 ]] || { print -u2 'Use Gitleaks 8.30.1 for your architecture.'; exit 1; }
mkdir -p .build/audit
archive="$PWD/.build/audit/gitleaks.tar.gz"
if [[ ! -f $archive ]]; then
    curl --fail --location --silent --show-error 'https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_darwin_arm64.tar.gz' -o "$archive"
fi
[[ $(shasum -a 256 "$archive" | cut -d ' ' -f 1) == b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ]] || { print -u2 'Gitleaks checksum mismatch'; exit 1; }
tar -xzf "$archive" -C .build/audit
.build/audit/gitleaks git --redact --no-banner --log-opts='--all'
