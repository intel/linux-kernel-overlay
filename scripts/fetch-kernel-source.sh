#!/bin/bash
# Fetch the upstream kernel source tarball, trying each candidate source in
# scripts/kernel-sources.yaml in order and moving on to the next one when a
# source fails (HTTP error, timeout, checksum mismatch, bad signature).
#
# Every source gives the same result: linux-{ver}.tar.xz with top-level
# directory linux-{ver}/. It is kept once in build/cache/ and hard-linked to
# OUTPUT, so the deb and RPM builds share one download.
#
# Usage: scripts/fetch-kernel-source.sh [--refresh] VERSION OUTPUT
#   --refresh  download again even if build/cache/ already has the tarball
#   VERSION    upstream version, Debian spelling (6.18.60, 6.18, 7.3~rc3)
#   OUTPUT     file to create
# KERNEL_SOURCES=<file> overrides the candidate list.

REFRESH=false
if [ "$1" = --refresh ]; then
	REFRESH=true
	shift
fi
VER=$1
OUT=$2
if [ -z "$VER" ] || [ -z "$OUT" ]; then
	echo "Usage: $0 [--refresh] VERSION OUTPUT"
	exit 1
fi

TOP=$(cd "$(dirname "$0")/.." && pwd)
TAG_VER=${VER/\~rc/-rc}		# kernel.org/git spelling: 7.3~rc3 -> 7.3-rc3
MAJOR=${VER%%.*}
TARBALL=linux-$TAG_VER.tar.xz
CACHE=$TOP/build/cache
SHARED=$CACHE/$TARBALL
PART=$SHARED.part.$$
SIGNING_KEYS=$TOP/debian/upstream/signing-key.asc
IS_RC=false
case "$VER" in *rc*) IS_RC=true ;; esac

log() { echo "[fetch] $*"; }

# Don't leave a partial download or a kernel clone behind in build/cache/
# when the build is interrupted.
GIT_TMP=
trap 'rm -rf "$PART" ${GIT_TMP:+"$GIT_TMP"}' EXIT
trap 'exit 130' INT TERM

# Hard-link the shared tarball to OUTPUT, or copy it if OUTPUT is on another
# file system.
place() {
	[ "$OUT" -ef "$SHARED" ] && return 0
	mkdir -p "$(dirname "$OUT")" || return 1
	ln -f "$SHARED" "$OUT" 2>/dev/null || cp -f "$SHARED" "$OUT"
}

mkdir -p "$CACHE" || exit 1
if ! $REFRESH && [ -f "$SHARED" ]; then
	log "using $SHARED, downloaded earlier"
	place || { log "cannot create $OUT"; exit 1; }
	exit 0
fi

LIST=${KERNEL_SOURCES:-$(dirname "$0")/kernel-sources.yaml}
if [ ! -f "$LIST" ]; then
	echo "Error: source list not found: $LIST"
	exit 1
fi

# Record in the log whether the list in use is the shipped one.
EXPECTED_LIST_SHA=$(cut -d' ' -f1 "$(dirname "$0")/kernel-sources.yaml.sha256" 2>/dev/null)
LIST_SHA=$(sha256sum < "$LIST" | cut -d' ' -f1)
if [ -z "$EXPECTED_LIST_SHA" ]; then
	log "WARNING: kernel-sources.yaml.sha256 missing, cannot tell if $LIST was modified"
	log "  sha256 $LIST_SHA"
elif [ "$LIST_SHA" = "$EXPECTED_LIST_SHA" ]; then
	log "source list: $LIST (sha256 $LIST_SHA, unmodified)"
else
	log "WARNING: $LIST has been edited, it differs from the shipped kernel-sources.yaml"
	log "  sha256 $LIST_SHA, expected $EXPECTED_LIST_SHA"
	log "  Continuing with the edited list."
fi

# Validate the YAML list and flatten its enabled entries to
# "<type> TAB <name> TAB <url>" lines, with {major} and {ver} expanded.
ENTRIES=$(python3 - "$LIST" "$MAJOR" "$TAG_VER" <<'EOF'
import sys
import yaml

path, major, ver = sys.argv[1:]

def die(msg):
    sys.exit(f"Error: {path}: {msg}")

try:
    with open(path) as f:
        doc = yaml.safe_load(f)
except yaml.YAMLError as e:
    die(f"invalid YAML: {e}")

if not isinstance(doc, dict):
    die("expected the top-level keys 'checksums' and 'sources'")
unknown = set(doc) - {"checksums", "sources"}
if unknown:
    die(f"unknown top-level key(s): {', '.join(sorted(map(str, unknown)))}")

for section in ("checksums", "sources"):
    entries = doc.get(section) or []
    if not isinstance(entries, list):
        die(f"'{section}' must be a list")
    allowed = {"name", "url", "enabled"} | ({"type"} if section == "sources" else set())
    for i, e in enumerate(entries):
        where = f"{section}[{i}]"
        if not isinstance(e, dict):
            die(f"{where}: expected 'name:', 'url:' ... fields")
        unknown = set(e) - allowed
        if unknown:
            die(f"{where}: unknown field(s): {', '.join(sorted(map(str, unknown)))}")
        url = e.get("url")
        if not isinstance(url, str) or not url:
            die(f"{where}: 'url' is required")
        enabled = e.get("enabled", True)
        if not isinstance(enabled, bool):
            die(f"{where}: 'enabled' must be true or false")
        if section == "checksums":
            kind = "checksum"
        else:
            kind = e.get("type")
            if kind not in ("tarball", "git"):
                die(f"{where}: 'type' must be tarball or git, not {kind!r}")
        if not enabled:
            continue
        name = str(e.get("name") or url).replace("\t", " ")
        print(kind, name, url.replace("{major}", major).replace("{ver}", ver), sep="\t")
EOF
) || exit 1

# Download failures stop after 20s without a connection or 60s below 1 KB/s,
# so a dead mirror costs a minute at most instead of hanging the build.
fetch() { curl -fsSL --retry 2 --connect-timeout 20 --speed-limit 1024 --speed-time 60 "$@"; }

try_tarball() {
	if ! fetch -o "$PART" "$1"; then
		rm -f "$PART"
		return 1
	fi
	local got
	got=$(sha256sum "$PART" | cut -d' ' -f1)
	if [ "$got" != "$SHA256" ]; then
		log "    sha256 mismatch: got $got, expected $SHA256"
		rm -f "$PART"
		return 1
	fi
}

# Shallow-clone the tag, check its signature against the keys in
# debian/upstream/signing-key.asc and archive it as linux-{ver}/.
try_git() {
	if [ ! -f "$SIGNING_KEYS" ]; then
		log "    $SIGNING_KEYS missing, cannot verify the tag"
		return 1
	fi
	local tmp out rc=1
	tmp=$(mktemp -d "$CACHE/git.XXXXXX") || return 1
	GIT_TMP=$tmp
	(
		set -o pipefail
		export GIT_HTTP_LOW_SPEED_LIMIT=1024 GIT_HTTP_LOW_SPEED_TIME=60
		export GNUPGHOME=$tmp/gnupg
		if ! { mkdir -m 700 "$GNUPGHOME" &&
		       gpg --batch --quiet --import "$SIGNING_KEYS" 2>/dev/null; }; then
			log "    cannot import $SIGNING_KEYS"
			exit 1
		fi
		git -c advice.detachedHead=false clone --quiet --depth 1 \
			--branch "v$TAG_VER" "$1" "$tmp/src" || exit 1
		# Pin the OpenPGP check, whatever gpg.* the user's git config sets.
		if ! out=$(git -C "$tmp/src" -c gpg.format=openpgp -c gpg.program=gpg \
				verify-tag "v$TAG_VER" 2>&1); then
			log "    signature check of tag v$TAG_VER failed:"
			sed 's/^/      /' <<< "$out" | tail -4
			exit 1
		fi
		log "    $(grep -o 'Good signature from.*' <<< "$out" | head -1)"
		git -C "$tmp/src" archive --format=tar --prefix="linux-$TAG_VER/" "v$TAG_VER" |
			xz -T0 > "$PART"
	) && rc=0
	GNUPGHOME=$tmp/gnupg gpgconf --kill all 2>/dev/null
	rm -rf "$tmp"
	GIT_TMP=
	[ $rc = 0 ] || rm -f "$PART"
	return $rc
}

# Released tarballs are verified against the first checksum list that
# has an entry for them.
SHA256=
if ! $IS_RC; then
	while IFS=$'\t' read -r type name url; do
		[ "$type" = checksum ] || continue
		SHA256=$(fetch "$url" | awk -v f="$TARBALL" '$2 == f {print $1}')
		[ -n "$SHA256" ] && { log "sha256 of $TARBALL from $name"; break; }
		log "no checksum for $TARBALL from $name ($url)"
	done <<< "$ENTRIES"
fi

CANDIDATES=$(grep -cE '^(tarball|git)	' <<< "$ENTRIES")
if [ "$CANDIDATES" = 0 ]; then
	echo "Error: $LIST: no enabled sources"
	exit 1
fi
n=0
# Read the list on fd 3 so curl/git inside the loop cannot eat it via stdin.
while IFS=$'\t' read -r type name url <&3; do
	case "$type" in tarball|git) ;; *) continue ;; esac
	n=$((n + 1))
	tag="[$n/$CANDIDATES] $name ($type)"
	if [ "$type" = tarball ]; then
		if $IS_RC; then
			log "$tag: skipped (-rc releases are git-only)"
			continue
		fi
		if [ -z "$SHA256" ]; then
			log "$tag: skipped (no checksum to verify it)"
			continue
		fi
	fi
	log "$tag: $url"
	if try_$type "$url"; then
		mv -f "$PART" "$SHARED" && place || { log "cannot create $OUT"; exit 1; }
		log "$tag: OK, $SHARED"
		exit 0
	fi
	log "$tag: FAILED, trying next source"
done 3<<< "$ENTRIES"

log "All $CANDIDATES sources failed for $VER (list: $LIST)"
exit 1
