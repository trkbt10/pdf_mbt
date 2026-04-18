#!/usr/bin/env bash
set -euo pipefail

spec_dir="$1"
impl_dir="$2"

indexion spec align status "$spec_dir/requirements.md" "$impl_dir" \
  --threshold 0.3 --fail-on drifted

indexion plan refactor --threshold=0.85 --include='*.mbt' \
  --exclude='*_wbtest.mbt' --exclude='*pkg.generated*' \
  "$impl_dir" > /tmp/refactor-after.md

# Compare function duplicate count with the previous baseline and fail if it
# increased. Exact baseline storage and comparison are left to the SDD that
# copies this snippet, because each spec owns its before/after report paths.
