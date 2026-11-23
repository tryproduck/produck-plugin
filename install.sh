#!/bin/sh
set -eu
umask 077
home="${PRODUCK_HOME:-$HOME/.produck}"
fail() { printf '%s\n' "$*" >&2; exit 1; }
value() { sed -n "s/^$1=//p" "$release" | head -n 1; }

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
node=node
case "$os" in
  mingw* | msys*) os=win32; node=node.exe ;;
esac
case "$arch" in
  x86_64 | amd64) arch=x64 ;;
  aarch64) arch=arm64 ;;
esac
[ "$os-$arch" != darwin-x64 ] || fail "Intel Macs aren't supported yet"
download="$(mktemp -d)"
trap 'rm -rf "$download"' EXIT
release="${PRODUCK_RELEASE_ENV:-}"
if [ -z "$release" ]; then
  case "$0" in
    */produck-bootstrap) release="$(dirname "$0")/release.env" ;;
  esac
fi
if [ ! -f "$release" ]; then
  base="${PRODUCK_RELEASE_URL:-https://github.com/tryproduck/produck-plugin/releases/download/v0.1.0-test.36.1}"
  [ "$base" != __PRODUCK_RELEASE_URL__ ] || fail "Use install.sh from a GitHub Release, or set PRODUCK_RELEASE_URL to its download URL"
  release="$download/release.env"
  curl --fail -sSL -o "$release" "$base/release.env" || fail "Could not download release.env"
fi
grep -q '^SHA256_' "$release" || fail "Development build: run ./run.sh in the Produck checkout"
expected="$(value "SHA256_$(printf '%s_%s' "$os" "$arch" | tr '[:lower:]' '[:upper:]')")"
if [ -z "$expected" ]; then
  supported="$(sed -n 's/^SHA256_\([A-Z0-9]*\)_\([A-Z0-9]*\)=.*/\1-\2/p' "$release" | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')"
  fail "Produck has no release for $os-$arch. Supported: $supported"
fi
version="$(value VERSION)"
base="$(value BASE_URL)"
[ -n "$version" ] && [ -n "$base" ] || fail "release.env names no VERSION or no BASE_URL"
printf '%s' "$version" | grep -Eq '^[0-9]+[.][0-9]+[.][0-9]+-(test[.])?[0-9]+[.][0-9]+$' || fail "Invalid release version"
printf '%s' "$expected" | grep -Eq '^[a-f0-9]{64}$' || fail "Invalid release SHA-256"

archive="produck-$version-$os-$arch.tar.gz"
curl --fail -sSL -o "$download/$archive" "$base/$archive" || fail "Could not download $base/$archive"
if command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$download/$archive" | cut -d ' ' -f 1)"
else
  actual="$(sha256sum "$download/$archive" | cut -d ' ' -f 1)"
fi
[ "$actual" = "$expected" ] || fail "SHA-256 mismatch for $archive: expected $expected, got $actual"

app="$home/app/$version"
mkdir -p "$home/app"
rm -rf "$app.partial"
mkdir "$app.partial"
tar -xzf "$download/$archive" -C "$app.partial"
cp "$release" "$app.partial/release.env"
rm -rf "$app"
mv "$app.partial" "$app"
PATH="$app:$PATH" "$app/$node" "$app/produck.cjs" setup "$@"
