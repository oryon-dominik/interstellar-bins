#!/bin/sh
# Lay out the Corresponding Source of one crate version: the crate as crates.io
# published it, its vendored dependencies, and the licence notices of everything the
# binary links. The build reads nothing else — what ships as source is what was built.
#
# Usage: scripts/source.sh <crate> <version> <out-dir>
# Needs: curl, jq, sha256sum, cargo, cargo-about
set -eu

name=$1
version=$2
out=$3
repo=$(cd "$(dirname "$0")/.." && pwd)

mkdir -p "$out"
# Absolute, because the steps below run cargo from inside the crate directory.
out=$(cd "$out" && pwd)
crate="$out/$name-$version.crate"
curl --silent --show-error --fail --location --output "$crate" \
    "https://static.crates.io/crates/$name/$version/download"

# The sparse index records the checksum of every published version; a download
# that does not match it is not the crate we mean to ship.
lower=$(printf %s "$name" | tr '[:upper:]' '[:lower:]')
case ${#lower} in
    1) index="1/$lower" ;;
    2) index="2/$lower" ;;
    3) index="3/$(printf %s "$lower" | cut -c1)/$lower" ;;
    *) index="$(printf %s "$lower" | cut -c1-2)/$(printf %s "$lower" | cut -c3-4)/$lower" ;;
esac
checksum=$(curl --silent --show-error --fail "https://index.crates.io/$index" |
    jq --raw-output --arg version "$version" 'select(.vers == $version) | .cksum')
echo "$checksum  $crate" | sha256sum --check --quiet

tar --extract --gzip --file "$crate" --directory "$out"
src="$out/$name-$version"
mkdir -p "$src/.cargo"
(cd "$src" && cargo vendor --locked --versioned-dirs vendor) >"$src/.cargo/config.toml"

licenses="$out/licenses"
mkdir -p "$licenses/$name"
found=$(find "$src" -maxdepth 1 -type f \( -iname 'LICEN[CS]E*' -o -iname 'COPYING*' \))
if [ -z "$found" ]; then
    echo "error: $name $version ships no licence file — nothing to redistribute under" >&2
    exit 1
fi
for file in $found; do
    cp "$file" "$licenses/$name/"
done
(cd "$src" && cargo about generate --config "$repo/licensing/about.toml" --locked \
    --output-file "$licenses/THIRD-PARTY-LICENSES.html" "$repo/licensing/third-party-licenses.hbs")
cp "$repo"/licensing/runtime/* "$licenses/"

# The build scripts belong to the Corresponding Source as well.
mkdir -p "$out/build"
cp -r "$repo/scripts" "$repo/licensing" \
    "$repo/.github/workflows/build.yml" "$out/build/"
tar --create --gzip --file "$out/$name-$version-source.tar.gz" --directory "$out" \
    "$name-$version" build
