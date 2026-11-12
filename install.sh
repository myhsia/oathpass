#!/bin/sh
# Install a released oathpass binary.
#
# Binaries are built by CI, never by hand: this script downloads the asset for
# this machine, verifies it against the release's SHA256SUMS, installs it
# atomically and runs --selftest.  If the selftest fails, the previous binary is
# put back.
#
#   curl -fsSL https://raw.githubusercontent.com/myhsia/oathpass/main/install.sh | sh
#   sh install.sh --version 0.3.0 --prefix "$HOME/.local/bin"
#
# Options:
#   --version V   release to install (default: the latest release)
#   --prefix D    install directory (default: ~/.local/bin)
#   --dry-run     print what would be installed, download nothing
set -eu

REPO="myhsia/oathpass"
VERSION=""
PREFIX="${HOME}/.local/bin"
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --prefix) PREFIX="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h | --help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
    esac
done

die() { echo "install.sh: $*" >&2; exit 1; }

detect_target() {
    system="$(uname -s)"
    machine="$(uname -m)"
    case "$system" in
        Darwin) os="macos" ;;
        Linux) os="linux" ;;
        MSYS* | MINGW* | CYGWIN*) os="windows" ;;
        *) die "unsupported system '$system'" ;;
    esac
    case "$machine" in
        arm64 | aarch64) arch="arm64" ;;
        x86_64 | amd64) arch="amd64" ;;
        *) die "unsupported machine '$machine'" ;;
    esac
    case "$os:$arch" in
        macos:arm64 | macos:amd64 | linux:arm64 | linux:amd64 | windows:amd64) ;;
        *) die "no released binary for $os-$arch; build from source with make" ;;
    esac
    TARGET="${os}-${arch}"
    # macOS gets one universal asset: under Rosetta uname reports x86_64 on an
    # arm64 Mac, so a per-arch choice there would be a guess.  Older releases
    # carry the two slices separately, hence the fallback.
    if [ "$os" = "macos" ]; then
        TARGETS="macos-universal macos-${arch}"
    else
        TARGETS="$TARGET"
    fi
}

latest_version() {
    if command -v gh >/dev/null 2>&1; then
        gh release view --repo "$REPO" --json tagName -q .tagName 2>/dev/null | sed 's/^v//' && return 0
    fi
    curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1
}

fetch() {
    # $1 asset, $2 destination directory
    url="https://github.com/${REPO}/releases/download/v${VERSION}/$1"
    if curl -fsSL -o "$2/$1" "$url" 2>/dev/null; then
        return 0
    fi
    if command -v gh >/dev/null 2>&1; then
        gh release download "v${VERSION}" --repo "$REPO" --pattern "$1" --dir "$2" --clobber 2>/dev/null && return 0
    fi
    return 1
}

detect_target
[ -n "$VERSION" ] || VERSION="$(latest_version)"
[ -n "$VERSION" ] || die "cannot determine the latest release; pass --version"

destination="${PREFIX}/oathpass"
[ "$TARGET" = "windows-amd64" ] && destination="${PREFIX}/oathpass.exe"

echo "target   ${TARGETS%% *}"
echo "release  v${VERSION}"
echo "install  ${destination}"
[ "$DRY_RUN" -eq 1 ] && exit 0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

downloaded=0
for candidate in $TARGETS; do
    case "$candidate" in
        windows-*) name="oathpass-${VERSION}-${candidate}.exe" ;;
        *) name="oathpass-${VERSION}-${candidate}" ;;
    esac
    if fetch "$name" "$tmp"; then
        asset="$name"
        downloaded=1
        break
    fi
done
[ "$downloaded" -eq 1 ] || die "cannot download ${VERSION}: no asset for ${TARGETS} (does that release exist?)"
echo "asset    ${asset}"
fetch SHA256SUMS "$tmp" || die "cannot download SHA256SUMS for v${VERSION}"

if command -v sha256sum >/dev/null 2>&1; then
    sum() { sha256sum "$1" | cut -d' ' -f1; }
else
    sum() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi
expected="$(awk -v a="$asset" '$2 == a { print $1 }' "$tmp/SHA256SUMS")"
[ -n "$expected" ] || die "${asset} is not listed in SHA256SUMS"
actual="$(sum "$tmp/$asset")"
[ "$expected" = "$actual" ] || die "checksum mismatch for ${asset}
  expected ${expected}
  actual   ${actual}"

chmod 755 "$tmp/$asset"
if ! "$tmp/$asset" --selftest >/dev/null; then
    die "the downloaded binary failed --selftest; nothing installed"
fi

mkdir -p "$PREFIX"
previous=""
if [ -f "$destination" ]; then
    previous="${tmp}/previous"
    cp "$destination" "$previous"
fi
# mv within one filesystem is atomic, so a half-written binary never appears
install -m 755 "$tmp/$asset" "${destination}.new"
mv -f "${destination}.new" "$destination"

if ! "$destination" --selftest >/dev/null; then
    if [ -n "$previous" ]; then
        mv -f "$previous" "$destination"
        die "the installed binary failed --selftest; the previous one is back in place"
    fi
    rm -f "$destination"
    die "the installed binary failed --selftest and no previous one existed"
fi

echo "installed $("$destination" --version) at ${destination}"
