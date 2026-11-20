# avocado-container-agent-dev

The device-side agent for Container Dev Mode. It stays **ring-only**: the
rustls crypto provider must be `ring`, and `aws-lc-rs` is forbidden.

## Why ring-only (aws-lc-rs forbidden)

The agent cross-compiles against the musl SDK (assumption A9), which clears only
the `ring` stack for the target - `aws-lc-rs` will not build there. This is the
same rule `avocado-conn` enforces. `aws-lc-rs` most commonly sneaks in through a
default rustls feature (e.g. `tokio-tungstenite`'s or `reqwest`'s default TLS),
so `Cargo.toml` disables default features on every TLS-touching dependency and
pins `ring` explicitly (including the `rcgen` dev-dependency, so aws-lc-rs stays
out of the tree entirely - dev-deps included).

## Provider guard: `scripts/check-provider.sh`

`scripts/check-provider.sh` asserts the crypto provider by inspecting the
dependency tree. It uses a three-way exit contract - a naive `! cargo tree` is
wrong, because `cargo tree -i <pkg>` exits 0 when the package is present and
non-zero (with `did not match any packages`) when absent, so a bare negation
would treat every network or manifest failure as a pass.

| Exit | Meaning |
|------|---------|
| 0 | Clean: aws-lc-rs absent, ring present. |
| 1 | aws-lc-rs is in the tree (forbidden provider present). |
| 2 | Guard error: tree unresolvable (network, bad manifest, unresolvable target, or ring missing). Never treated as a pass. |

The guard also backstops by asserting `ring` IS present: a guard that cannot see
`ring` cannot trust its aws-lc-rs result, so that case exits 2.

### Enforced gate vs advisory run

- **Enforced gate (in CI, with `TARGET`):** the `binaries` job in
  `.github/workflows/release.yml` runs the guard as
  `TARGET=<rust-target> scripts/check-provider.sh` immediately before
  `cross build`, resolving the same musl triple the shipped binary is built
  for. A non-zero exit fails the job before anything is built or released. The
  `agent` job in `.github/workflows/test.yml` runs the same step on every pull
  request. This repository has no pre-commit hook, and `cad-compile.sh` no
  longer builds the crate, so these two jobs are the only enforcement points.
- **Advisory run (standalone, no `TARGET`):** running
  `scripts/check-provider.sh` directly (e.g. from the repo root) checks the
  **host** triple, not the shipped cross target. Treat it as an advisory
  smoke-check; it does not gate anything.

The guard uses the default `cargo tree` edge set (dev-dependencies included) and
deliberately does not pass `--edges normal,build` or `--locked`, so it resolves
the same tree the build does within the shared `CARGO_HOME`.
