# oathpass

Answer an SSH one-time-password prompt from a local seed, so a login needs no
phone, no typing of host or port, and no second terminal.

Some SSH gateways authenticate with a bare OATH/TOTP code and nothing else:

```
One-time password (OATH) for `user':
```

`oathpass` answers that prompt itself: it computes the RFC 6238 code from a
seed in a local config file, and hands it to `ssh` as the askpass program. The
code never appears on the command line, in a log, or in any client's saved
password store.

```console
$ oathpass                 # log in
$ oathpass run ls -la      # read-only remote command
$ oathpass sftp -b -       # batch sftp
$ oathpass rsync -av ./d/ :dest/
```

## The single-use rule

**A code is single-use.** Two logins inside the same window make the second
fail, and some clusters treat repeated failures as an attack. So the first
command opens one multiplexed master connection (`~/.cache/oathpass/`), and
every later command, `sftp`, `scp` and `rsync` rides that socket with **no
further authentication**. `oathpass close` drops it.

This is also why no credential is ever handed to a client: there is nothing to
save and nothing to replay.

## Build

```console
$ make                  # needs a C compiler, nothing else
$ make test             # replays the RFC 6238 vectors
$ make install          # to $(PREFIX)/bin, default ~/.local/bin
$ make check            # install, then selftest and PATH check
```

The build output is the command: no interpreter, no wrapper script, no
bytecode cache. `oathpass --version` prints the release.

## First run

`oathpass` and any command that needs a config print a numbered guide and leave
a mode-600 skeleton at `~/.config/oathpass/config.json` when the file is
missing or still holds placeholders.

With a terminal attached, `oathpass --init` collects the values itself. The
OTP URI is read with the terminal echo off — the mechanism `sudo` uses — so the
seed never appears on screen; the URI is validated before anything is written,
and the buffer holding it is wiped. Without a terminal it prints the guide and
exits 1 instead of blocking on a prompt.

```json
{
  "oathpass": {
    "host": "10.0.0.1",
    "ports": ["2201", "2202", "2203"],
    "user": "someone",
    "otp": {
      "uri": "otpauth://totp/...?secret=...&algorithm=SHA512&digits=8&period=30"
    }
  }
}
```

`otp.uri` is what an authenticator exports; its algorithm, digits and period
win. A bare `otp.secret` (base32) is accepted instead, defaulting to
SHA512/8 digits/30 s. `time_url` overrides the HTTPS host `doctor` asks for a
`Date:` header (default `https://1.1.1.1`).

The file holds the account's only factor: keep it mode 600, never commit it,
and never let an SFTP client save a code for the account.

## Commands

| command | purpose |
|---|---|
| `oathpass [ssh args…]` | log in, reusing the master if it is up |
| `oathpass run <cmd> [args…]` | read-only remote command inside `$HOME` |
| `oathpass sftp -b FILE\|-` | batch sftp (interactive sftp is refused) |
| `oathpass scp <args…>` | scp; `:path` means `<user>@<host>:path` |
| `oathpass rsync <args…>` | rsync over the master, same path rules |
| `oathpass check` | dry run: node, code, ssh line; nothing sent |
| `oathpass otp [--at EPOCH]` | print the current code |
| `oathpass port` / `target` | the chosen port / `user@host` |
| `oathpass status` / `close` | master state / drop it |
| `oathpass sockpath` | the socket, for `rsync -e` and friends |
| `oathpass doctor` | why a code does not match the authenticator |
| `oathpass --init [--force]` | guided set-up of the config |
| `oathpass --selftest` | replay the RFC 6238 vectors |
| `--node N` / `--port P` | pin one login node |

## What the guard is and is not

`oathpass run` allows only `ls cat grep head tail wc stat file du df md5sum
shasum find pwd`, refuses absolute paths, `~`, `..` and shell syntax before a
connection opens, and blocks `find -exec/-delete/-fprint…`. `scp`, `sftp` and
`rsync` apply the same rule to remote paths.

**It is a tripwire, not a jail.** The account is a full shell, so a deliberate
escape is always possible. Real isolation has to be server-side (`chroot`,
`ForceCommand`); with OATH-only authentication there is no `authorized_keys
command=` to hook.

## Licence

MIT — see `LICENSE`.
