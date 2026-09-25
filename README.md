# interstellar-bins

Prebuilt Linux binaries of open-source Rust crates that publish none of their own —
so a server installs them in seconds with
[cargo-binstall](https://github.com/cargo-bins/cargo-binstall) instead of compiling
for minutes or hours.

Every build is the unmodified crate as crates.io publishes it, compiled with
`--locked --offline` from its vendored sources. What is built, in which versions and
for which targets, is [`manifest/crates.json`](manifest/crates.json); what is out
there is the [releases page](https://github.com/oryon-dominik/interstellar-bins/releases).

## Install

```bash
cargo binstall cfonts@1.3.0 \
  --pkg-url 'https://github.com/oryon-dominik/interstellar-bins/releases/download/{ name }-{ version }/{ name }-{ version }-{ target }{ archive-suffix }' \
  --pkg-fmt tgz \
  --bin-dir '{ bin }{ binary-ext }' \
  --disable-strategies quick-install,compile
```

cargo-binstall cannot verify a signature for a crate whose `Cargo.toml` it does not
control. Each archive has a `.sha256` beside it — check it before you trust the binary:

```bash
sha256sum --check cfonts-1.3.0-x86_64-unknown-linux-musl.tar.gz.sha256
```

## Releases

One release per crate version, tagged `<crate>-<version>`:

| Asset | What it is |
|---|---|
| `<crate>-<version>-<target>.tar.gz` | The binaries, with `licenses/` beside them |
| `<crate>-<version>-<target>.tar.gz.sha256` | Its checksum |
| `<crate>-<version>-source.tar.gz` | The Corresponding Source: the crate, its vendored dependencies and the build scripts |
| `<crate>-<version>.crate` | The crate exactly as crates.io serves it |
| `<crate>-<version>-licenses.tar.gz` | The licence texts on their own |

A published release is never rebuilt or replaced, and its source stays for as long as
its binaries do.

## Adding a crate

One entry in `manifest/crates.json`, pushed — nothing else. The build workflow compares
the manifest with the releases and builds only what they lack: a new version gets its
own release, a new target joins the existing one, built from the source archive
already published there.

```json
{ "name": "cfonts", "version": "1.3.0", "targets": ["x86_64-unknown-linux-musl", "aarch64-unknown-linux-musl"] }
```

A crate qualifies when it publishes no binaries of its own and a node needs it.
A dependency under a licence that `licensing/about.toml` does not accept stops the
build — read what that licence asks of a redistributor before you add it.

## Licences

The files of this repository — scripts, workflows, templates — are MIT licensed
(`LICENSE`). **The binaries are not**: each one carries the licence of its crate. A
GPL-licensed crate stays GPL, and its release carries the complete source it was
built from.

Every archive holds a `licenses/` directory with the crate's own licence, the notices
of every statically linked dependency, and the notices of musl and the Rust standard
library. What goes in there, and why, is in [`licensing/`](licensing/README.md).

## How a build works

The workflow runs three scripts, in this order — each also runs on its own, on Linux:

| Script | What it does |
|---|---|
| `scripts/plan.sh` | Lists the archives the releases lack |
| `scripts/source.sh <crate> <version> <out>` | Fetches the crate, checks it against the crates.io index, vendors its dependencies, collects the licences, packs the source archive |
| `scripts/build.sh <crate> <version> <target> <out>` | Unpacks that source archive and builds from it offline — the binary provably comes from the source that ships |

`source.sh` needs `cargo-about`; `plan.sh` needs `gh` inside a checkout of this
repository.
