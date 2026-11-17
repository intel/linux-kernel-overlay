#!/bin/bash
# Fetch the upstream kernel source tarball, trying each candidate source in
# scripts/kernel-sources.yaml in order and moving on to the next one when a
# source fails (HTTP error, timeout, checksum mismatch, git error).
#
# Usage: scripts/fetch-kernel-source.sh VERSION OUTPUT
#   VERSION  upstream version, Debian spelling (6.18.60, 6.18, 7.3~rc3)
#   OUTPUT   .orig.tar.xz file to create
# Run from the source tree root: git sources use uscan with debian/watch.
# KERNEL_SOURCES=<file> overrides the candidate list.

VER=$1
OUT=$2
if [ -z "$VER" ] || [ -z "$OUT" ]; then
	echo "Usage: $0 VERSION OUTPUT"
	exit 1
fi

LIST=${KERNEL_SOURCES:-$(dirname "$0")/kernel-sources.yaml}
if [ ! -f "$LIST" ]; then
	echo "Error: source list not found: $LIST"
	exit 1
fi

TAG_VER=${VER/\~rc/-rc}		# kernel.org/git spelling: 7.3~rc3 -> 7.3-rc3
MAJOR=${VER%%.*}
TARBALL=linux-$TAG_VER.tar.xz
WATCH_REPO=$(grep -oE 'https?://[^ ]+\.git' debian/watch 2>/dev/null | head -1)
IS_RC=false
case "$VER" in *rc*) IS_RC=true ;; esac

log() { echo "[fetch] $*"; }

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
	if ! fetch -o "$OUT.part" "$1"; then
		rm -f "$OUT.part"
		return 1
	fi
	local got
	got=$(sha256sum "$OUT.part" | cut -d' ' -f1)
	if [ "$got" != "$SHA256" ]; then
		log "    sha256 mismatch: got $got, expected $SHA256"
		rm -f "$OUT.part"
		return 1
	fi
	mv -f "$OUT.part" "$OUT"
}

try_git() {
	if [ -z "$WATCH_REPO" ]; then
		log "    no git repository URL found in debian/watch"
		return 1
	fi
	local tmp file rc=1
	tmp=$(mktemp -d "$(dirname "$OUT")/uscan.XXXXXX") || return 1
	# Point debian/watch's repository at this candidate without touching
	# anybody's ~/.gitconfig: git reads extra config from GIT_CONFIG_*.
	(
		if [ "$1" != "$WATCH_REPO" ]; then
			export GIT_CONFIG_COUNT=1
			export GIT_CONFIG_KEY_0="url.$1.insteadOf"
			export GIT_CONFIG_VALUE_0="$WATCH_REPO"
		fi
		export GIT_HTTP_LOW_SPEED_LIMIT=1024 GIT_HTTP_LOW_SPEED_TIME=60
		uscan --download --rename --destdir "$tmp" --download-version="$VER"
	)
	file=$(find "$tmp" -maxdepth 1 -type f -name '*.orig.tar.xz' | head -1)
	if [ -n "$file" ]; then
		mv -f "$file" "$OUT" && rc=0
	fi
	rm -rf "$tmp"
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
# Read the list on fd 3 so curl/uscan inside the loop cannot eat it via stdin.
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
		log "$tag: OK, $(basename "$OUT")"
		exit 0
	fi
	log "$tag: FAILED, trying next source"
done 3<<< "$ENTRIES"

log "All $CANDIDATES sources failed for $VER (list: $LIST)"
exit 1
