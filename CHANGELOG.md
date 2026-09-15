# Changelog

All notable changes to avocado-ext-container-agent-dev are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
