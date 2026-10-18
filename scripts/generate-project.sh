#!/bin/bash
set -euo pipefail

# Keep XcodeGen's temporary files and cache inside this repository.
task_root="$(cd "$(dirname "$0")/.." && pwd)"
generation_dir="$task_root/.build/validation/xcodegen"
mkdir -p "$generation_dir/tmp"
export TMPDIR="$generation_dir/tmp/"

exec xcodegen generate \
    --spec "$task_root/project.yml" \
    --project-root "$task_root" \
    --project "$task_root" \
    --cache-path "$generation_dir/spec.cache"
