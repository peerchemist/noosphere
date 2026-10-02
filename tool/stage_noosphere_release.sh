#!/usr/bin/env bash
set -euo pipefail

# Stage the shared package outside the repository: pub inherits the root
# .pubignore, which excludes packages/ from the Flutter facade archive.
# This copies the current working files and never publishes anything.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_dir="$(mktemp -d "${TMPDIR:-/tmp}/noosphere-release.XXXXXX")"
trap 'rm -rf "$release_dir"' ERR

while IFS= read -r -d '' file; do
  relative="${file#packages/noosphere/}"
  [[ -f "$repo_root/$file" ]] || continue
  mkdir -p "$release_dir/$(dirname "$relative")"
  cp "$repo_root/$file" "$release_dir/$relative"
done < <(git -C "$repo_root" ls-files -z --cached --others --exclude-standard -- packages/noosphere/)

# The standalone archive has no workspace parent. Runtime dependencies remain
# hosted constraints; no dependency overrides are injected.
sed '/^resolution: workspace$/d' "$release_dir/pubspec.yaml" > "$release_dir/pubspec.yaml.tmp"
mv "$release_dir/pubspec.yaml.tmp" "$release_dir/pubspec.yaml"
printf '%s\n' "$release_dir"
