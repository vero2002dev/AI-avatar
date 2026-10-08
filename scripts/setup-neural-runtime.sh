#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
python="${1:-python3}"
root="$repo_dir/build/neural-runtime"
"$python" -c 'import sys; assert sys.version_info >= (3, 11), "Python 3.11+ required"'
mkdir -p "$root"
if [[ ! -d "$root/engine/.git" ]]; then
    git clone https://github.com/ivanfioravanti/fasterliveportrait-mlx.git "$root/engine"
fi
git -C "$root/engine" checkout --detach d5361f4806c14fe2051eecb1dd5a89930f46db0d
"$python" -m venv "$root/venv"
"$root/venv/bin/python" -m pip install -r "$repo_dir/neural/requirements.txt"
"$root/venv/bin/python" "$repo_dir/neural/setup_runtime.py" --root "$root"
