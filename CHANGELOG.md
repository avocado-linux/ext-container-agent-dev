# Changelog

All notable changes to avocado-ext-container-agent-dev are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

### Changed
- The extension ships a prebuilt agent binary instead of its source. `avocado
  ext package` runs no build step, so the published RPM could only carry what
  was in the repo; shipping the crate pushed the compile onto consumers, who
  have no Rust cross toolchain in their SDK and no reason to. A clean project
  following the documented setup failed inside `ring`'s build script with
  `ToolNotFound: failed to find tool "x86_64-avocado-linux-gcc"`, after both
  `avocado install` and the extension's own sysroot creation reported success.
- Binaries are statically linked against musl, so they carry no libc version
  coupling and run on any Avocado target of the right architecture.
- `release.yml` builds x86_64 and aarch64 binaries, verifies each is static and
  the right architecture, and attaches them with a `SHA256SUMS` to the release
  before the extension publishes.
- `cad-install.sh` checks the staged binary's architecture against the target
  before installing. The packaged extension is noarch and nothing downstream
  re-checks, so a mismatch would otherwise install cleanly and fail at exec time
  on the device.

### Removed
- The Rust cross toolchain from the extension's SDK requirements, and `libstd-rs`
  from the compile section. Nothing compiles at build time any more.
- The crate source from `package_files`. The RPM is no longer a source package.

## [0.1.1]

### Fixed
- The release matrix varied the build target rather than the feed, so both rows
  published the same version into `2024/next` and the second failed with "that
  extension version is already taken". An extension version is global within a
  distro release and channel, and Connect fans a published extension out to the
  per-target feeds on its own, so the matrix now varies release and channel and
  covers both `2026/next` and `2024/next`.

### Note
- `0.1.0` reached `2024/next` from the successful leg of that partial release and
  was never published to `2026/next`. `0.1.1` is the first version present in
  both feeds.

## [0.1.0]

### Added
- Initial release: the Container Dev Mode device agent, its build hooks, the
  systemd path and service units, and the packaging manifest.
- The agent crate, carried over with its history rather than as a flat copy.
- Target-triple resolution that enumerates candidates and refuses an ambiguous
  match instead of taking whichever the glob returned first, and that skips the
  SDK's own nativesdk triple. Without the skip, x86_64 matches both the device
  triple and the SDK's and resolution refuses.
- CI via the shared `avocado-linux/actions` reusable workflows: PR build check
  (`test.yml`) and tag-driven package + publish to the Avocado feed
  (`release.yml`).
