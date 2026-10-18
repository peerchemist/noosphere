#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
proto_dir="$repo_root/proto"
generated_dir="$repo_root/lib/src/generated"
plugin="$repo_root/tool/protoc-gen-dart-local"

generate_into() {
  local output_dir="$1"
  local full_output_dir
  full_output_dir="$(mktemp -d)"
  mkdir -p "$output_dir"
  (
    cd "$repo_root"
    protoc \
      --plugin="protoc-gen-dart=$plugin" \
      --proto_path="$proto_dir" \
      --dart_out="$full_output_dir" \
      noosphere.proto
  )
  cp "$full_output_dir/noosphere.pb.dart" "$output_dir/"
  cp "$full_output_dir/noosphere.pbenum.dart" "$output_dir/"
  cp "$full_output_dir/noosphere.pbjson.dart" "$output_dir/"
  rm -rf "$full_output_dir"
}

if [[ "${1:-}" == "--check" ]]; then
  check_dir="$(mktemp -d)"
  trap 'rm -rf "$check_dir"' EXIT
  generate_into "$check_dir"
  diff -ru "$generated_dir" "$check_dir"
else
  generate_into "$generated_dir"
fi
