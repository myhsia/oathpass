---
name: oathpass
description: Work on the oathpass repository — build, test, version and release the C tool that answers OATH/TOTP SSH prompts. Use when changing src/oathpass.c, the Makefile, the CI workflows, or when cutting a release.
license: MIT
compatibility: opencode
metadata:
  audience: maintainers
  scope: repository
---

# oathpass (repository work)

Read `AGENTS.md` at the repository root first: it is the authoritative guide
for layout, build, versioning and style. This skill is the working procedure.

## Packaging rule

**Release, never hand-build.** A change is not finished until CI has published
it: `VERSION` bumped, tag `v<VERSION>` pushed, the workflow green on all five
targets, and `install.sh` able to fetch the new asset. `make install` is a
development shortcut; the binary in `~/.local/bin` comes from a release.

## Before changing code

- Read `src/oathpass.c`'s header comment: it states the model (single-use code,
  one multiplexed master, the guard's limits) in the order the code is arranged.
- Keep it one translation unit with no dependencies. A new dependency means
  `make` no longer works on a bare Linux runner or under MSYS2, and the CI
  matrix is what proves that.

## The loop

```console
make && make test && sh tests/ci-check.sh ./oathpass
```

- `make test` replays the RFC 6238 vectors. If it fails, the vendored hash or
  HMAC is wrong — do not touch the vectors, they are the published table.
- `tests/ci-check.sh` runs the CLI and guard paths offline. A new command needs
  a case there, including the refusal path if it can touch a path.
- CI adds `-Werror` on three systems. clang and gcc disagree about warnings
  (notably `-Wformat-truncation`), so avoid composing paths through fixed
  buffers with `%s` sources of known range; build them from `getenv` results
  and check the return value.

## Adding a command

1. Add the mode to `usage()`, the header comment, and the `with_config` list in
   `main` (or the pre-config branch if it needs no config).
2. Validate anything user-supplied **before** `ensure_master()`, so a refusal
   costs no connection and is testable offline.
3. Add the CI case, then update `README.md`'s command table and `AGENTS.md` if
   the layout changed.

## Cutting a release

```console
$EDITOR VERSION         # 0.1.1, no leading v
git commit -am "release: v0.1.1"
git tag v0.1.1 && git push && git push --tags
```

The workflow refuses a tag that disagrees with `VERSION` (`v<VERSION>-rcN` is
allowed for a dry run, and is published as a prerelease). It builds
linux-{amd64,arm64} (static musl, the arm64 one under qemu), macos-{arm64,amd64}
(the x86 one under Rosetta), and windows-amd64 (MSYS2), runs `--selftest` on
each, and publishes `SHA256SUMS` beside the assets. Watch it:

```console
gh run list --workflow release --limit 1
gh run watch
gh release view v0.1.1
```

## Never

- Never commit `~/.config/oathpass/config.json` content, a real `otpauth://`
  URI, or a host/user pair. The test seed is the RFC 6238 key, which is public.
- Never make the tool read a code from argv or an environment variable: it
  would land in shell history and in `ps`.
