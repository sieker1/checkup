#!/bin/bash
# Prints an SDK path this machine's swiftc can actually read.
#
# The newest Command Line Tools SDK can be newer than the installed compiler
# (it refuses it: "this SDK is not supported by the compiler"). Probe the
# installed SDKs newest-first and print the first one that typechecks a
# one-line file, falling back to xcrun's default so the caller always gets a
# path. Pass the target triple as $1 if it differs from the default below.

set -uo pipefail

target="${1:-arm64-apple-macosx15.0}"

# Probing costs a few seconds per rejected SDK, so remember the answer next to
# the build products. The cache is keyed on the compiler version, so updating
# the Command Line Tools re-probes instead of trusting a stale path.
cache="${PICK_SDK_CACHE:-.build/sdk-path}"
cache_key="$(swiftc --version 2>/dev/null | head -n 1)"
if [ -f "$cache" ] && [ -f "$cache.key" ] && [ "$(cat "$cache.key")" = "$cache_key" ]; then
  cached="$(cat "$cache")"
  if [ -e "$cached" ]; then
    echo "$cached"
    exit 0
  fi
fi

probe="$(mktemp -d 2>/dev/null)" || exit 1
trap 'rm -rf "$probe"' EXIT
printf 'let _ = 1\n' > "$probe/probe.swift"

candidates=()
for dir in /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk; do
  [ -e "$dir" ] || continue   # an unexpanded glob means no SDKs are installed
  candidates+=("$dir")
done

default="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
[ -n "$default" ] && candidates+=("$default")

if [ "${#candidates[@]}" -eq 0 ]; then
  echo "pick-sdk.sh: no macOS SDK found (is the Command Line Tools package installed?)" >&2
  exit 1
fi

# `sort -Vr` puts 26.5 above 26 and 15.4, so we prefer the newest SDK the
# compiler accepts rather than whichever happens to come first on disk.
while IFS= read -r sdk; do
  if swiftc -typecheck -target "$target" -sdk "$sdk" "$probe/probe.swift" >/dev/null 2>&1; then
    mkdir -p "$(dirname "$cache")" 2>/dev/null
    printf '%s\n' "$sdk" > "$cache" 2>/dev/null
    printf '%s\n' "$cache_key" > "$cache.key" 2>/dev/null
    echo "$sdk"
    exit 0
  fi
done < <(printf '%s\n' "${candidates[@]}" | sort -u | sort -Vr)

# Nothing typechecked; hand back xcrun's answer so the failure surfaces in the
# real build with a useful error instead of an empty -sdk argument.
echo "$default"
