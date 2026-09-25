# Licensing

Everything a release needs to meet the licences of what its binaries contain.
`scripts/source.sh` reads this directory and writes the result into the `licenses/`
directory of every archive.

| Path | What it does |
|---|---|
| `about.toml` | [cargo-about](https://github.com/EmbarkStudios/cargo-about) configuration: the licences a linked crate may carry. A dependency under any other licence stops the build — add one only after reading what it asks of a redistributor. |
| `third-party-licenses.hbs` | The template cargo-about renders into `THIRD-PARTY-LICENSES.html`: every statically linked crate with its full licence text. |
| `runtime/` | The notices of the runtime every binary links statically, which cargo-about cannot see because they are not crates. |

## Why `runtime/` exists

The binaries are built for `*-unknown-linux-musl`, so two pieces of code end up
inside every one of them without appearing in any `Cargo.lock`:

- **musl**, the C library — MIT. Its copyright notice must travel with every copy:
  `musl-COPYRIGHT`.
- **The Rust standard library** — MIT or Apache-2.0. Shipped under MIT, which asks
  for the copyright notice and the licence text: `rust-COPYRIGHT`,
  `rust-LICENSE-MIT`.

cargo-about reads the crate graph only, so without these files a binary would ship
code whose licence it does not name.
