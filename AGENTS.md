# oathpass

An askpass program for SSH gateways that authenticate with a bare OATH/TOTP
code, plus a multiplexed master connection, a guarded read-only runner, and
`scp`/`sftp`/`rsync` wrappers that ride it. One C translation unit, no
dependencies. MIT.

## Layout

| path | what |
|---|---|
| `src/oathpass.c` | the whole tool |
| `tests/ci-check.sh` | CLI checks CI runs: no network, no secret |
| `VERSION` | single source of truth, compiled in by the Makefile |
| `.github/workflows/ci.yml` | build, selftest, CLI checks, install, on Ubuntu/macOS/Windows(MSYS2) |
| `.github/workflows/release.yml` | on `v*` tags: verify the tag, build, publish |

## Build and test

```console
make                 # -O2 -Wall -Wextra -Werror
make test            # RFC 6238 vectors, no config needed
make check           # install, then selftest and a PATH check
make install         # PREFIX/bin, default ~/.local/bin
```

`CFLAGS` is overridable from the command line; `DEFINES` carries
`-DOATHPASS_VERSION` and is never overridden, so a `make CFLAGS=…` still stamps
the version.

## Money

Slurm bills allocated cores per started hour. `job submit` plans first, needs
`--time`, and refuses above `spend_limit` (¥7.80) without `--yes`; the default
pick is the fastest plan within the cap, `--cheap` takes the cheapest. Keep the
partition table (`rate`, `cores`, `min_cores`) honest — the daily rate check in
`~/.config/opencode/skills/opencode-hpc-update` compares it with the published
page.

## Versioning and releasing

1. Bump `VERSION`, commit.
2. `git tag v<VERSION>` and push the tag.
3. The release workflow refuses a tag that disagrees with `VERSION`, builds
   macOS and Linux binaries, runs `--selftest` on each, and publishes a release
   with the artifacts attached. A tag containing `-` is published as a
   prerelease.

Never commit the built binary: `/oathpass` is ignored.

## Style

- C builds warning-free under `-Wall -Wextra -Werror` with both clang and gcc.
- No third-party dependency. SHA-1/256/512 and HMAC live in `src/oathpass.c`;
  `--selftest` pins them to the RFC 6238 vectors, so a crypto change that
  breaks is caught without a network or a secret.
- The machine-global rules in `~/.config/opencode/AGENTS.md` still apply: the
  commit gate, the guide check, and "no secrets in commits".

## Secrets

The tool holds none. Credentials live in `~/.config/oathpass/config.json`
(mode 600), outside every repository. A test seed is the published RFC 6238
key and nothing else.
