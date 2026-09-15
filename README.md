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
| `agent/` | the Rust crate, cross-compiled at package time |
| `cad-compile.sh` | resolves the target triple and builds the crate |
| `cad-install.sh` | stages the built binary into the extension sysroot |
| `cad-clean.sh` | clears the build directory |
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

The SDK image tag is release-scoped and comes from the environment, so export it
before building:

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
been seen to exec on that architecture. The release matrix in
`.github/workflows/release.yml` should carry one row per declared target.

## Releasing

Tag the version in `avocado.yaml`. The release workflow guards that the tag and
the manifest version match, packages one leg per matrix row, and publishes each
to the feed derived from that row's distro release and channel.

Bump `release:` whenever the packaged payload changes without a version change.
An unchanged version-release identity means the package manager never delivers
the new payload to a device that already has the extension installed, and both
the build and the install report success anyway.
