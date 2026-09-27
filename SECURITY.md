# Security

## Reporting a vulnerability

Please **don't open a public issue.** Report it privately through GitHub:
**Security → Report a vulnerability** on this repository. You'll get a reply within a
week, and credit in the release notes if you'd like it.

Useful in a report: the Danny version (*About Danny*), macOS version, what an attacker
can do, and steps or a proof of concept.

## What's in scope

- Danny itself: the app, Browser Capture, the download queue, update and release
  artifacts (DMG, zip, checksums).
- How Danny runs the tools it bundles (yt-dlp, ffmpeg) and, from M2, plugins —
  e.g. a crafted URL, page or media file that makes Danny run something it shouldn't.

Vulnerabilities in yt-dlp or ffmpeg themselves belong upstream; we'll ship their
fixes by bumping the pinned versions (`scripts/fetch-dependencies.sh`).

## Supported versions

Only the latest release gets fixes. Releases are signed and notarized once the
project's Developer ID is in place; every release lists SHA-256 checksums.
