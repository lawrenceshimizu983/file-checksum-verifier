#!/usr/bin/env bash
# file_checksum_verifier.sh - compute and verify SHA-256 checksums against a manifest.
#
# Design decisions:
# - SHA-256 is computed with sha256sum because it is part of coreutils and therefore
#   always present in the target environment. No third-party tools are used.
# - The manifest format is deliberately simple: one record per line, "<hex-digest>  <path>".
#   Two spaces separate the digest from the path so that paths may contain spaces.
# - Comments (#) and blank lines are ignored when reading a manifest. This makes it
#   possible to keep human notes alongside the checksums.
# - Verification is strict: a file is only considered verified when its computed digest
#   exactly matches the digest recorded in the manifest, case-insensitively.
# - The library does not change directory. Callers pass paths relative to the current
#   working directory, and the manifest records those same paths. This keeps the
#   behaviour predictable and avoids surprising path rewriting.

set -euo pipefail

# Print the SHA-256 digest of a single file.
# Usage: file_checksum_verifier_sha256 FILE
# Exits non-zero if the file cannot be read.
file_checksum_verifier_sha256() {
    local file="$1"
    sha256sum -- "$file" | awk '{print $1}'
}

# Read a manifest and print one line per entry in the form "digest path".
# Blank lines and lines whose first non-space character is '#' are skipped.
# Usage: file_checksum_verifier_read_manifest MANIFEST
file_checksum_verifier_read_manifest() {
    local manifest="$1"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip leading whitespace to detect comments and blanks.
        local trimmed="${line#"${line%%[![:space:]]*}"}"
        if [[ -z "$trimmed" || "$trimmed" == \#* ]]; then
            continue
        fi
        # The digest is the first field; the path is everything after the two spaces.
        local digest="${line%% *}"
        local rest="${line#* }"
        # Remove the single separating space that follows the digest field.
        local path="${rest# }"
        printf '%s %s\n' "$digest" "$path"
    done < "$manifest"
}

# Verify every entry in a manifest.
# Prints a TAP-like line per entry and returns 0 only if all entries match.
# Usage: file_checksum_verifier_verify MANIFEST
file_checksum_verifier_verify() {
    local manifest="$1"
    local failures=0
    local count=0

    while IFS= read -r entry; do
        count=$((count + 1))
        local expected="${entry%% *}"
        local path="${entry#* }"

        if [[ ! -f "$path" ]]; then
            printf 'not ok %d - %s: missing file\n' "$count" "$path"
            failures=$((failures + 1))
            continue
        fi

        local actual
        if ! actual=$(file_checksum_verifier_sha256 "$path"); then
            printf 'not ok %d - %s: unreadable\n' "$count" "$path"
            failures=$((failures + 1))
            continue
        fi

        # Compare case-insensitively: hex digests are case-insensitive by definition.
        if [[ "${actual,,}" == "${expected,,}" ]]; then
            printf 'ok %d - %s\n' "$count" "$path"
        else
            printf 'not ok %d - %s: expected %s got %s\n' \
                "$count" "$path" "$expected" "$actual"
            failures=$((failures + 1))
        fi
    done < <(file_checksum_verifier_read_manifest "$manifest")

    if (( failures > 0 )); then
        return 1
    fi
    return 0
}
