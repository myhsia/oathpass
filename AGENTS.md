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
```

Building is for development. **Users install a release, never a local build**:
`install.sh` downloads this machine's asset, verifies `SHA256SUMS`, installs
atomically and runs `--selftest`, restoring the previous binary if that fails.

`CFLAGS` is overridable from the command line; `DEFINES` carries
`-DOATHPASS_VERSION` and is never overridden, so a `make CFLAGS=…` still stamps
the version.

## Versioning and releasing

1. Bump `VERSION`, commit.
2. `git tag v<VERSION>` and push the tag.
3. The release workflow refuses a tag that disagrees with `VERSION` (a
   `v<VERSION>-rcN` candidate is allowed), builds five targets, runs `--selftest`
   on each, and publishes the assets plus `SHA256SUMS`. A tag containing `-` is
   published as a prerelease.

The five targets, and how each is proven:

| target | build | executed in CI |
|---|---|---|
| linux-amd64 | native, static musl | native `--selftest` |
| linux-arm64 | `zig cc` aarch64-musl, static | `qemu-aarch64-static` |
| macos-arm64 | native | native |
| macos-amd64 | `-arch x86_64` | `arch -x86_64` under Rosetta |
| macos-universal | `lipo -create` of both | both slices, natively and under Rosetta |
| windows-amd64 | MSYS2 `gcc` | native |

`macos-universal` is the asset the installer prefers on macOS: `uname -m` reports `x86_64` on an
arm64 Mac whenever the shell is running under Rosetta, so a per-arch choice there would be a guess.
The two per-arch slices are still published for pinned and embedded use.

A target is released only if its binary *ran* the selftest. `windows-arm64` is
not released: MSYS2 has no Cygwin layer for it, so the source would need a native
Win32 port first, and no runner here can execute an aarch64 Windows binary.

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
