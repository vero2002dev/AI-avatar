#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
root="$repo_dir/build/neural-runtime"
bundle="${1:-$repo_dir/build/AIAvatar.app}"
destination="$bundle/Contents/Resources/Neural"
[[ -x "$root/venv/bin/python" ]] || { printf 'Run setup-neural-runtime.sh first.\n' >&2; exit 1; }
base="$($root/venv/bin/python -c 'import sys; print(sys.base_prefix)')"
version="$($root/venv/bin/python -c 'import sys; print(f"python{sys.version_info.major}.{sys.version_info.minor}")')"
mkdir -p "$destination/python/lib/$version/site-packages"
# Ship a relocatable interpreter and its standard library, not an external
# executable requiring access outside the app sandbox.
rsync -a --exclude site-packages --exclude __pycache__ --exclude lib/pkgconfig --exclude share/man "$base/" "$destination/python/"
# Some standalone Python distributions contain broken optional documentation
# links; code signing refuses such links even though the interpreter ignores them.
rm -f "$destination/python/lib/pkgconfig/python3.pc" "$destination/python/lib/pkgconfig/python3-embed.pc" "$destination/python/share/man/man1/python3.1"
rsync -a --exclude __pycache__ "$root/venv/lib/$version/site-packages/" "$destination/python/lib/$version/site-packages/"
ditto "$root/engine/src" "$destination/engine/src"
ditto "$root/engine/LICENSE" "$destination/engine/LICENSE"
ditto "$root/engine/NOTICE.md" "$destination/engine/NOTICE.md"
ditto "$root/weights" "$destination/weights"
ditto "$repo_dir/neural/worker.py" "$destination/worker.py"
while IFS= read -r -d '' library; do codesign --force --sign - "$library"; done < <(find "$destination/python" -type f \( -name '*.so' -o -name '*.dylib' \) -print0)
interpreter="$(readlink "$destination/python/bin/python3")"
codesign --force --sign - --entitlements "$repo_dir/neural/Helper.entitlements" "$destination/python/bin/$interpreter"
codesign --force --sign - --options runtime --entitlements "$repo_dir/AIAvatar/AIAvatar.entitlements" "$bundle"
codesign --verify --deep --strict "$bundle"
printf 'Bundled sandbox-inheriting neural runtime: %s\n' "$bundle"
