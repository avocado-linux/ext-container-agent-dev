# ext-template

GitHub template repo for new Avocado extensions. **Use this template** → then work
through the checklist below.

## New-extension checklist

1. Rename the repo `ext-<name>` (or `bsp-<board>`).
2. `avocado.yaml` — rename the extension key to `avocado-ext-<name>`, fill in
   `summary`/`description`, set `supported_targets` (and `default_target` for a BSP),
   list your `packages`. Leave the `sdk.image` line alone.
3. `.github/workflows/test.yml` — set the matrix `target` to something the extension
   actually supports (`qemux86-64` is fine for target-agnostic extensions).
4. `.github/workflows/release.yml` — same, plus add matrix rows for every feed you
   publish into.
5. `CHANGELOG.md` — replace the placeholder `0.1.0` entry.
6. Delete this section from the README and describe the extension instead (see
   "Using this extension" below — keep that part).
7. Repo secrets `AVOCADO_CONNECT_TOKEN` and `AVOCADO_CONNECT_ORG` must be set (org-level
   secrets cover this if the repo is in `avocado-linux`).

Release: tag the commit with the exact `avocado.yaml` version, e.g. `git tag 0.1.0 && git push --tags`.

## Conventions

- **SDK image is release-scoped, not channel-scoped.**
  `docker.io/avocadolinux/sdk:{{ env.AVOCADO_DISTRO_RELEASE }}` → `avocadolinux/sdk:2026`
  on a 2026 CI leg, `avocadolinux/sdk:2024` on a 2024 one. Do not append
  `-{{ env.AVOCADO_DISTRO_CHANNEL }}` — there is no such tag on any release. The channel
  selects the *package feed*; the image tag is per-release only.
- **CI comes from `avocado-linux/actions@v1`**, pinned. The matrix lives in the caller so
  each repo owns its own target/feed combinations.
- **Feed today is `2024`/`edge-next`.** `avocado-linux/actions@v1` *defaults* to
  `2026`/`edge`, but the 2026 feed currently publishes only `jetson-agx-thor`, so the
  workflows here pass 2024 explicitly. Move a target to 2026 as it lands there.

## Using this extension

`ext-template` is an [Avocado](https://avocadolinux.org) extension — a reusable fragment of
build- and runtime-configuration that you compose into your own Avocado project. To use it,
declare it as a package-sourced extension in your `avocado.yaml` and add it to a runtime:

```yaml
extensions:
  avocado-ext-template:
    source:
      type: package
      version: "*"        # or pin an exact version

runtimes:
  my-runtime:
    extensions:
      - avocado-ext-template
```

Then install and build:

```sh
avocado install   # fetches + installs the SDK, extensions and runtime deps from your config
avocado build     # builds the SDK compile steps, extensions and runtime images
```

`avocado install` pulls the extension from your target's package feed and merges its
config into your project; `avocado build` then produces the runtime.
