#!/bin/bash
# Kernel package verifier
#   1. Validates that kernel binary version matches module directory name
#   2. (optional) Verifies that every Intel-requested kernel config option in
#      intel/config/amd64/intel/*.cfg is actually honored in the final config
#      shipped by the linux-config-*.deb package.

set -e

BINARY_DEB="$1"
MODULES_DEB="$2"
CONFIG_DEB="$3"

if [ -z "$BINARY_DEB" ] || [ -z "$MODULES_DEB" ]; then
    echo "Usage: $0 <linux-image-*.deb> <linux-modules-*.deb> [linux-config-*.deb]"
    echo ""
    echo "  linux-image/modules debs  : version-consistency check (required)"
    echo "  linux-config deb          : Intel config-coverage check (optional)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directory holding the Intel-requested config fragments (overridable via env).
INTEL_CONFIG_DIR="${INTEL_CONFIG_DIR:-$SCRIPT_DIR/../intel/config/amd64/intel}"
# RT-only fragment (Intel-requested PREEMPT_RT options); checked only for RT images.
RT_CONFIG_FILE="${RT_CONFIG_FILE:-$SCRIPT_DIR/../intel/config/config.rt}"
# Symbols that debian/rules.real strips from the shipped config; they cannot be
# verified from the packaged config and are reported as skipped rather than failed.
STRIPPED_SYMS="CONFIG_MODULE_SIG_ALL CONFIG_MODULE_SIG_KEY CONFIG_SYSTEM_TRUSTED_KEYS CONFIG_BUILD_SALT"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

OVERALL_FAIL=0

echo "=== Kernel Package Verifier ==="
echo ""

# Extract binary package
echo "[1/6] Extracting binary package..."
dpkg-deb -x "$BINARY_DEB" "$TMPDIR/binary" >/dev/null 2>&1

# Extract modules package
echo "[2/6] Extracting modules package..."
dpkg-deb -x "$MODULES_DEB" "$TMPDIR/modules" >/dev/null 2>&1

# Find kernel binary
KERNEL_FILE=$(find "$TMPDIR/binary/boot" -name "vmlinuz-*" | head -1)
if [ ! -f "$KERNEL_FILE" ]; then
    echo "❌ ERROR: No kernel binary found in package!"
    exit 1
fi

# Extract kernel version from binary
echo "[3/6] Extracting kernel version from binary..."
KERNEL_VERSION=$(file "$KERNEL_FILE" | grep -oP 'version \K[^, ]+')

if [ -z "$KERNEL_VERSION" ]; then
    echo "❌ ERROR: Could not extract kernel version from binary!"
    exit 1
fi

# Is this a PREEMPT_RT image? (drives RT-specific checks below)
case "$KERNEL_VERSION" in
    *-rt*) IS_RT=1 ;;
    *)     IS_RT=0 ;;
esac

# Find module directory
echo "[4/6] Checking module directory..."
MODULE_DIR=$(ls "$TMPDIR/modules/usr/lib/modules/" 2>/dev/null || ls "$TMPDIR/modules/lib/modules/" 2>/dev/null)

if [ -z "$MODULE_DIR" ]; then
    echo "❌ ERROR: No module directory found in package!"
    exit 1
fi

# Check RT kernel parameter file (for RT kernels only)
echo "[5/6] Checking RT kernel parameter file (if RT kernel)..."
RT_CHECK_RESULT=""
if [ "$IS_RT" -eq 1 ]; then
    RT_PARAM_FILE=$(find "$TMPDIR/binary/usr/share/doc" -name "kernel-rt-parameter" 2>/dev/null)
    if [ -n "$RT_PARAM_FILE" ]; then
        FILE_SIZE=$(stat -f%z "$RT_PARAM_FILE" 2>/dev/null || stat -c%s "$RT_PARAM_FILE" 2>/dev/null)
        RT_CHECK_RESULT="✅ RT parameter file found (${FILE_SIZE} bytes)"
    else
        RT_CHECK_RESULT="⚠️  WARNING: RT parameter file not found (RT boot parameters will not be applied)"
    fi
fi

# Display version results
echo ""
echo "📦 Binary package:  $(basename "$BINARY_DEB")"
echo "📦 Modules package: $(basename "$MODULES_DEB")"
echo ""
echo "🔍 Kernel binary version:  $KERNEL_VERSION"
echo "📁 Module directory name:   $MODULE_DIR"
if [ -n "$RT_CHECK_RESULT" ]; then
    echo "⚙️  RT parameter check:     $RT_CHECK_RESULT"
fi
echo ""

# Verify version/module-dir match
if [ "$KERNEL_VERSION" = "$MODULE_DIR" ]; then
    echo "✅ Version check: kernel version and module directory match"
else
    echo "❌ Version check FAILED: version mismatch detected!"
    echo ""
    echo "⚠️  This will cause boot failure:"
    echo "    • Kernel will identify as: $KERNEL_VERSION"
    echo "    • But modprobe will look in: /lib/modules/$MODULE_DIR/"
    echo "    • Result: No modules can be loaded (including critical drivers like NVMe)"
    echo ""
    echo "💡 Fix: Ensure CONFIG_LOCALVERSION is set correctly in kernel config"
    echo "    See debian/rules.real for LOCALVERSION_IMAGE configuration"
    OVERALL_FAIL=1
fi
echo ""

# ---------------------------------------------------------------------------
# [6/6] Intel config-coverage check (only when a linux-config deb is supplied)
# ---------------------------------------------------------------------------
echo "[6/6] Checking Intel config coverage..."
if [ -z "$CONFIG_DEB" ]; then
    echo "  ⏭️  Skipped: no linux-config-*.deb supplied (pass it as the 3rd argument)."
    echo ""
elif [ ! -d "$INTEL_CONFIG_DIR" ]; then
    echo "  ⚠️  WARNING: Intel config fragment dir not found: $INTEL_CONFIG_DIR"
    echo ""
else
    dpkg-deb -x "$CONFIG_DEB" "$TMPDIR/config" >/dev/null 2>&1

    # The linux-config deb ships one config.<arch>_<featureset>_<flavour>.xz per
    # build (e.g. config.amd64_none_amd64.xz, config.amd64_none_rt-amd64.xz).
    # Pick the flavour whose name is the longest matching suffix of this kernel's
    # version, so an "-rt-amd64" image selects the rt config, not the plain one.
    FINAL_XZ=""
    BEST_LEN=-1
    while IFS= read -r f; do
        base=$(basename "$f" .xz)          # config.amd64_none_rt-amd64
        flav=${base#config.*_*_}           # rt-amd64  (strip "config.<arch>_<fs>_")
        if [ "$flav" = "$base" ]; then      # fallback if pattern didn't match
            flav=${base##*_}
        fi
        if [[ "$KERNEL_VERSION" == *-"$flav" ]] && [ "${#flav}" -gt "$BEST_LEN" ]; then
            BEST_LEN=${#flav}
            FINAL_XZ="$f"
        fi
    done < <(find "$TMPDIR/config" -name 'config.*.xz')

    if [ -z "$FINAL_XZ" ]; then
        echo "  ⚠️  WARNING: could not find a config matching '$KERNEL_VERSION' in $(basename "$CONFIG_DEB")"
        echo "      Available: $(find "$TMPDIR/config" -name 'config.*.xz' -printf '%f ' 2>/dev/null)"
        echo ""
    else
        FINAL_CONFIG="$TMPDIR/final.config"
        xzcat "$FINAL_XZ" > "$FINAL_CONFIG"

        # Fragment set to verify. For RT images also include the RT-only fragment
        # (intel/config/config.rt), whose options Intel requests for PREEMPT_RT.
        # Literal glob (no nullglob): an empty dir yields a bogus path that awk
        # fails to open, surfacing as a loud error rather than a silent 0-checked pass.
        FRAG_FILES=("$INTEL_CONFIG_DIR"/*.cfg)
        FRAG_DISPLAY="$INTEL_CONFIG_DIR/*.cfg"
        if [ "$IS_RT" -eq 1 ]; then
            if [ -f "$RT_CONFIG_FILE" ]; then
                FRAG_FILES+=("$RT_CONFIG_FILE")
                FRAG_DISPLAY="$FRAG_DISPLAY + $(basename "$RT_CONFIG_FILE")"
            else
                echo "  ⚠️  WARNING: RT image but RT config not found: $RT_CONFIG_FILE"
            fi
        fi
        echo "  Fragments: $FRAG_DISPLAY"
        echo "  Final cfg: $(basename "$FINAL_XZ")  (from $(basename "$CONFIG_DEB"))"
        echo ""

        CONFIG_REPORT="$TMPDIR/config.report"
        CONFIG_STATUS=0
        # awk: build the set of acceptable values per requested symbol (a symbol
        # requested with several values passes if the final matches ANY of them),
        # then compare against the final config. Exit 1 if any real mismatch.
        awk -v final="$FINAL_CONFIG" -v stripped="$STRIPPED_SYMS" '
            BEGIN {
                n = split(stripped, arr, " ")
                for (i = 1; i <= n; i++) skip[arr[i]] = 1
            }
            FILENAME == final {
                if ($0 ~ /^CONFIG_[A-Z0-9_]+=/) {
                    p = index($0, "="); s = substr($0, 1, p - 1)
                    act[s] = substr($0, p + 1); have[s] = 1
                } else if ($0 ~ /^# CONFIG_[A-Z0-9_]+ is not set/) {
                    act[$2] = "__NOTSET__"; have[$2] = 1
                }
                next
            }
            {
                if ($0 ~ /^CONFIG_[A-Z0-9_]+=/) {
                    p = index($0, "="); s = substr($0, 1, p - 1); v = substr($0, p + 1)
                } else if ($0 ~ /^# CONFIG_[A-Z0-9_]+ is not set/) {
                    s = $2; v = "__NOTSET__"
                } else {
                    next
                }
                if (!(s in seen_req)) { ord[++nord] = s; seen_req[s] = 1 }
                key = s SUBSEP v
                if (!(key in val_seen)) { val_seen[key] = 1; want[s] = want[s] (want[s] ? "\036" : "") v }
                if (!(s in src)) src[s] = FILENAME
                else if (index(src[s], FILENAME) == 0) src[s] = src[s] ", " FILENAME
            }
            END {
                total = 0; pass = 0; nerr = 0; nwarn = 0; nskip = 0
                for (i = 1; i <= nord; i++) {
                    s = ord[i]; total++
                    if (s in skip) { nskip++; skiprep[nskip] = s; continue }
                    m = split(want[s], accept, "\036")
                    cur = (s in have) ? act[s] : "__ABSENT__"
                    ok = 0
                    for (j = 1; j <= m; j++) {
                        e = accept[j]
                        if (e == "__NOTSET__") {
                            if (cur == "__NOTSET__" || cur == "__ABSENT__") ok = 1
                        } else if (cur == e) {
                            ok = 1
                        }
                    }
                    if (ok) { pass++; continue }
                    # Build compact one-line record.
                    reqtok = ""; reqEnabled = 0
                    for (j = 1; j <= m; j++) {
                        e = accept[j]
                        if (e == "y" || e == "m") reqEnabled = 1
                        t = (e == "__NOTSET__") ? "notset" : e
                        reqtok = reqtok (reqtok ? "|" : "") t
                    }
                    fintok = (cur == "__ABSENT__") ? "absent" : \
                             (cur == "__NOTSET__") ? "notset" : cur
                    src1 = src[s]; sub(/,.*/, "", src1)          # first source file
                    nb = split(src1, pp, "/"); base = pp[nb]     # basename
                    line = sprintf("  %-46s requested=%-10s final=%-10s (%s)", \
                        s, reqtok, fintok, base)
                    # Warning: option is still enabled in both, only builtin-vs-module
                    # differs (y<->m). Anything else (disabled/absent/other) is an error.
                    if (reqEnabled && (cur == "y" || cur == "m")) {
                        nwarn++; warn[nwarn] = line
                    } else {
                        nerr++; err[nerr] = line
                    }
                }
                if (nerr > 0) {
                    printf "\n  ── Config ERRORS — requested option not enabled in final (%d) ──\n", nerr
                    for (i = 1; i <= nerr; i++) print err[i]
                }
                if (nwarn > 0) {
                    printf "\n  ── Config warnings — enabled but builtin/module differs (%d) ──\n", nwarn
                    for (i = 1; i <= nwarn; i++) print warn[i]
                }
                printf "\n  Summary: %d requested, %d honored, %d error(s), %d warning(s), %d skipped\n", \
                    total, pass, nerr, nwarn, nskip
                if (nskip > 0) {
                    printf "  Skipped (stripped from shipped config, unverifiable):\n      "
                    for (i = 1; i <= nskip; i++) printf "%s ", skiprep[i]
                    printf "\n"
                }
                exit (nerr > 0) ? 1 : 0
            }
        ' "${FRAG_FILES[@]}" "$FINAL_CONFIG" > "$CONFIG_REPORT" 2>&1 || CONFIG_STATUS=$?
        cat "$CONFIG_REPORT"
        if [ "$CONFIG_STATUS" -eq 0 ]; then
            echo ""
            echo "✅ Config check passed (any warnings above are non-fatal: y↔m only)"
        else
            echo ""
            echo "❌ Config check FAILED: required Intel options not enabled in final config (see errors above)"
            OVERALL_FAIL=1
        fi
        echo ""
    fi
fi

# ---------------------------------------------------------------------------
# Final verdict
# ---------------------------------------------------------------------------
if [ "$OVERALL_FAIL" -eq 0 ]; then
    echo "✅ SUCCESS: all checks passed"
    exit 0
else
    echo "❌ FAILURE: one or more checks failed (see above)"
    exit 1
fi
