#!/bin/sh
# Decide what the build workflow does. A build is missing when its release lacks the
# archive for that target — so a new crate version builds everything, a new target
# builds only itself, and an interrupted upload is completed on the next run.
#
# A release that exists keeps everything it has: its missing archives are built from
# the source archive already published there, because the binary must match the
# source that ships beside it, and two builds are not bit-identical.
#
# Prints {"sources": [...], "builds": [...], "releases": [...]} as one JSON line.
# Usage: scripts/plan.sh [manifest/crates.json]
# Needs: gh (inside a checkout of this repository), jq
set -eu

manifest=${1:-$(cd "$(dirname "$0")/.." && pwd)/manifest/crates.json}

builds='[]'
count=$(jq '.crates | length' "$manifest")
i=0
while [ "$i" -lt "$count" ]; do
    crate=$(jq --compact-output ".crates[$i]" "$manifest")
    tag=$(printf %s "$crate" | jq --raw-output '.name + "-" + .version')
    if assets=$(gh release view "$tag" --json assets --jq '[.assets[].name]' 2>/dev/null); then
        released=true
        if ! printf %s "$assets" | jq --exit-status --arg file "$tag-source.tar.gz" 'index($file)' >/dev/null; then
            echo "error: release $tag has no $tag-source.tar.gz — binaries without their source" >&2
            exit 1
        fi
    else
        released=false
        assets='[]'
    fi
    builds=$(printf %s "$builds" | jq --compact-output \
        --argjson crate "$crate" --argjson assets "$assets" --argjson released "$released" \
        '. + [$crate.targets[]
              | select(($crate.name + "-" + $crate.version + "-" + . + ".tar.gz") as $file
                       | $assets | index($file) | not)
              | {name: $crate.name, version: $crate.version, target: ., released: $released,
                 runner: (if startswith("aarch64") then "ubuntu-24.04-arm" else "ubuntu-24.04" end)}]')
    i=$((i + 1))
done

printf %s "$builds" | jq --compact-output '{
    sources: [.[] | select(.released | not) | {name, version}] | unique,
    builds: .,
    releases: [.[] | {name, version, released}] | unique
}'
