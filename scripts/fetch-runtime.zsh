#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
[[ $(uname -m) == arm64 ]] || { print -u2 'This beta bundles Apple Silicon only.'; exit 1; }
runtime_tag='20260901'
runtime_name='cpython-3.12.14+20260901-aarch64-apple-darwin-install_only_stripped.tar.gz'
runtime_sha='81a359f1cfadd4da11766534c5913791cea55f26e1bb902cacd2a531bb1e4b2b'
runtime_url="https://github.com/astral-sh/python-build-standalone/releases/download/$runtime_tag/${runtime_name//+/%2B}"
mkdir -p .build/runtime
archive="$PWD/.build/runtime/$runtime_name"
if [[ ! -f $archive ]]; then
    curl --fail --location --retry 3 "$runtime_url" -o "$archive.partial"
    mv "$archive.partial" "$archive"
fi
actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
[[ $actual == $runtime_sha ]] || { print -u2 'Python archive checksum mismatch. Remove .build/runtime and retry.'; exit 1; }
if [[ ! -x .build/runtime/python/bin/python3 ]]; then tar -xzf "$archive" -C .build/runtime; fi
.build/runtime/python/bin/python3 -I -B -c 'import sqlite3, ssl; print("Bundled runtime ready")'
