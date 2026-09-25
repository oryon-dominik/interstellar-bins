#!/bin/sh
# Build one crate version for one target from the source archive scripts/source.sh
# wrote — offline, from the lockfile — and pack the binaries with their licences.
# Unpacking the archive itself proves the binary comes from the source that ships.
#
# Usage: scripts/build.sh <crate> <version> <target> <out-dir>
# Needs: rustup, cargo, jq, tar, sha256sum
set -eu

name=$1
version=$2
target=$3
out=$4
src="$out/$name-$version"

rm -rf "$src"
tar --extract --gzip --file "$out/$name-$version-source.tar.gz" --directory "$out"
rustup target add "$target"
# cargo finds the vendored sources through .cargo/config.toml, which it looks up
# from the working directory — hence the cd, not --manifest-path.
(cd "$src" && cargo build --release --locked --offline --target "$target")

package="$out/package/$name-$version-$target"
mkdir -p "$package"
bins=$(cd "$src" && cargo metadata --format-version 1 --no-deps --offline |
    jq --raw-output '.packages[].targets[] | select(.kind | index("bin")) | .name')
for bin in $bins; do
    cp "$src/target/$target/release/$bin" "$package/"
done
cp -r "$out/licenses" "$package/"

archive="$name-$version-$target.tar.gz"
tar --create --gzip --file "$out/$archive" --directory "$package" .
(cd "$out" && sha256sum "$archive" >"$archive.sha256")
