#!/usr/bin/env bash
# Tests for file_checksum_verifier.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=file_checksum_verifier.sh
source "$SCRIPT_DIR/file_checksum_verifier.sh"

# Simple TAP-like assertion helper.
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    if [[ "$expected" == "$actual" ]]; then
        printf 'ok - %s\n' "$message"
    else
        printf 'not ok - %s\n' "$message"
        printf '# expected: %s\n' "$expected"
        printf '# actual:   %s\n' "$actual"
        exit 1
    fi
}

# Create a temporary workspace that is removed even if a test fails.
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- file_checksum_verifier_sha256 ---

printf 'hello\n' > "$TMPDIR/hello.txt"
# Precomputed with sha256sum on the exact bytes "hello\n".
EXPECTED_HELLO="5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"
GOT_HELLO="$(file_checksum_verifier_sha256 "$TMPDIR/hello.txt")"
assert_eq "$EXPECTED_HELLO" "$GOT_HELLO" "sha256 of hello.txt"

# Empty file has a well-known digest.
: > "$TMPDIR/empty.txt"
EXPECTED_EMPTY="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
GOT_EMPTY="$(file_checksum_verifier_sha256 "$TMPDIR/empty.txt")"
assert_eq "$EXPECTED_EMPTY" "$GOT_EMPTY" "sha256 of empty file"

# --- file_checksum_verifier_read_manifest ---

cat > "$TMPDIR/manifest.txt" <<EOF
# a comment

${EXPECTED_HELLO}  hello.txt
${EXPECTED_EMPTY}  empty.txt
EOF

read_manifest_output="$(file_checksum_verifier_read_manifest "$TMPDIR/manifest.txt")"
expected_manifest="${EXPECTED_HELLO} hello.txt
${EXPECTED_EMPTY} empty.txt"
assert_eq "$expected_manifest" "$read_manifest_output" "manifest parsing skips comments and blanks"

# --- file_checksum_verifier_verify ---

# All files match.
(
    cd "$TMPDIR"
    output="$(file_checksum_verifier_verify manifest.txt)"
    expected="ok 1 - hello.txt
ok 2 - empty.txt"
    if [[ "$output" != "$expected" ]]; then
        printf 'not ok - verify all-match output\n'
        printf '# expected:\n%s\n' "$expected"
        printf '# actual:\n%s\n' "$output"
        exit 1
    fi
    printf 'ok - verify all-match output\n'
)

# One file is modified.
printf 'goodbye\n' > "$TMPDIR/hello.txt"
(
    cd "$TMPDIR"
    if file_checksum_verifier_verify manifest.txt >/dev/null 2>&1; then
        printf 'not ok - verify detects modification (expected failure)\n'
        exit 1
    fi
    printf 'ok - verify detects modification\n'
)

# Missing file is reported as a failure.
rm "$TMPDIR/hello.txt"
(
    cd "$TMPDIR"
    if file_checksum_verifier_verify manifest.txt >/dev/null 2>&1; then
        printf 'not ok - verify detects missing file (expected failure)\n'
        exit 1
    fi
    printf 'ok - verify detects missing file\n'
)

# Uppercase digest in the manifest still verifies.
printf 'hello\n' > "$TMPDIR/hello.txt"
UPPER_HELLO="$(printf '%s' "$EXPECTED_HELLO" | tr '[:lower:]' '[:upper:]')"
cat > "$TMPDIR/upper_manifest.txt" <<EOF
${UPPER_HELLO}  hello.txt
EOF
(
    cd "$TMPDIR"
    output="$(file_checksum_verifier_verify upper_manifest.txt)"
    assert_eq "ok 1 - hello.txt" "$output" "uppercase digest verifies"
)

# Paths with spaces are handled.
printf 'spaced\n' > "$TMPDIR/a file.txt"
SPACED_HASH="$(file_checksum_verifier_sha256 "$TMPDIR/a file.txt")"
cat > "$TMPDIR/space_manifest.txt" <<EOF
${SPACED_HASH}  a file.txt
EOF
(
    cd "$TMPDIR"
    output="$(file_checksum_verifier_verify space_manifest.txt)"
    assert_eq "ok 1 - a file.txt" "$output" "path with spaces"
)

printf '1..0 # all tests passed\n'
