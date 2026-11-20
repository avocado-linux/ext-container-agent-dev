# ext-container-agent-dev

`avocado-ext-container-agent-dev` - the device side of Container Dev Mode.

The agent holds a control WebSocket open to the host CLI, proxies image pulls
from the host's registry over a bootstrap-delivered pinned CA, and hot-reloads
the target container when a sync lands. It is what makes `avocado container dev`
transfer only the changed layer instead of a whole image.

**Development only.** This extension exists so it can be composed into a dev
runtime and left out of production. The `-dev` suffix is the gate. Do not ship it
on a production device.

## Layout

| Path | What it is |
|---|---|
| `agent/` | the Rust crate; the release workflow builds it into static musl binaries |
| `cad-compile.sh` | downloads the prebuilt binary for the target's architecture from the matching release and verifies it against `SHA256SUMS` |
| `cad-install.sh` | stages the binary into the extension sysroot |
| `cad-clean.sh` | removes the staged download and binary |
| `overlay/` | the `container-agent-dev` path and service units |
| `avocado.yaml` | extension manifest |

## Requires a container engine

The agent execs the engine CLI as its own child on every sync, so a runtime
without the `docker` extension gives it nothing to do. That dependency is stated
rather than declared: avocado-cli parses an inter-extension dependency and logs
it without installing anything, so declaring it would read as a guarantee and
deliver none. Compose both into the runtime yourself. The agent's startup
preflight is what makes a missing engine fail loudly rather than silently.

## Building locally

The build downloads the agent binary from the GitHub release named after the
`avocado.yaml` version, so it only works for a version that has been released.
An unreleased version fails the fetch with a 404. To build against binaries that
are not released, put the tarball and its `SHA256SUMS`, named as the release
workflow names them, in `dist/` next to `avocado.yaml`; `cad-compile.sh` verifies
and uses them instead of downloading. The SDK image tag is
release-scoped and comes from the environment, so export it before building:

```
AVOCADO_DISTRO_RELEASE=2024 avocado ext install -t qemux86-64 avocado-ext-container-agent-dev
AVOCADO_DISTRO_RELEASE=2024 avocado ext build   -t qemux86-64 avocado-ext-container-agent-dev
```

Two things that will otherwise cost you time:

- `avocado` runs its SDK container with a TTY, so a build launched without one
  fails with `cannot attach stdin to a TTY-enabled container`. Wrap it in
  `script -qefc '<cmd>' /dev/null` when running from CI or a background shell.
- dnf prompts for confirmation and blocks; `--no-tui` does not suppress it. Pass
  `--dnf-arg -y`.

## Supported targets

`avocado.yaml` lists them explicitly rather than using `'*'`. A target belongs
there once it has produced an installable package and the produced binary has
been seen to exec on that architecture. The release workflow does not need a
row per target: `binaries` builds one artifact per architecture, and `publish`
has one row per feed, as the header of `.github/workflows/release.yml` explains.

## Releasing

Tag the version in `avocado.yaml`. The release workflow first checks that the
tag and the manifest version match, then builds the agent binaries, attaches
them and `SHA256SUMS` to the GitHub release of that tag, and publishes the
extension to the feed derived from each `publish` row's distro release and
channel.

The `build` check in `test.yml` builds the extension against the release named
after the `avocado.yaml` version, because `cad-compile.sh` downloads the agent
binary from it. On a version-bump PR that release does not exist yet, so the
`release-exists` job finds that out and `build` is skipped, with the reason in
that job's log, instead of failing on a 404. On a PR that does not bump the
version, `build` exercises the last released binary, not the agent code in the
PR; the `agent` job compiles that code but does not package or install it.

The order is:

1. Merge the version-bump PR.
2. Push the version tag.
3. The release workflow builds both architectures, creates the release as a
   draft, uploads the assets and publishes the release.
4. `verify` builds the extension against that release for qemux86-64 and
   imx93-frdm on each publish feed.
5. The extension publish job runs.

A release is created once per tag. Re-running the workflow for a tag that
already has a release refuses instead of replacing its files, so a rebuilt
binary needs a new version. The feed index is rebuilt separately, so the new
package can appear after the release workflow finishes.

Bump `release:` whenever the packaged payload changes without a version change.
An unchanged version-release identity means the package manager never delivers
the new payload to a device that already has the extension installed, and both
the build and the install report success anyway.
