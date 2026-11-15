# file-checksum-verifier

A small Bash library that computes SHA-256 checksums for files and verifies them against a manifest.

## Usage

```bash
source file_checksum_verifier.sh

# Compute the SHA-256 digest of a single file.
file_checksum_verifier_sha256 path/to/file

# Verify every entry in a manifest. The manifest format is one record per line:
#   <hex-digest>  <path>
# Blank lines and lines starting with '#' are ignored.
file_checksum_verifier_verify manifest.txt
```

The exported functions are:

- `file_checksum_verifier_sha256 FILE` – prints the SHA-256 digest of `FILE`.
- `file_checksum_verifier_read_manifest MANIFEST` – prints each non-comment, non-blank manifest entry as `digest path`.
- `file_checksum_verifier_verify MANIFEST` – checks every entry and prints TAP-like `ok`/`not ok` lines; returns 0 only when all entries match.

## Why this exists

`sha256sum -c` already verifies checksum files, but its manifest format is strict and its output is not easy to consume from other scripts. This library keeps the manifest format simple and predictable while still allowing comments and paths that contain spaces. The trade-off is that it does not support the full GNU checksum-file grammar (for example, binary mode markers are not interpreted); it is a focused verifier, not a drop-in replacement for `sha256sum -c`.

## Edge cases

- A manifest entry whose file is missing or unreadable is reported as a failure, not a crash.
- Digest comparison is case-insensitive, so manifests produced on systems that emit uppercase hex still verify.
- Paths are taken literally from the manifest and are resolved relative to the current working directory; the library never changes directory on your behalf.
