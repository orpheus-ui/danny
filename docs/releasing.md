# Releasing

How a version of Danny gets from `development` to users. The pipeline lives in
`scripts/release.sh` and `.github/workflows/release.yml`; the decisions behind
it are ADR-010…012 in [decisions.md](decisions.md).

## Versions

- **SemVer**, `vMAJOR.MINOR.PATCH`. `0.x` until the public 1.0 launch; 0.x releases
  are marked as pre-releases on GitHub.
- The version lives in one place: `MARKETING_VERSION` in `project.yml`
  (`make version V=0.2.0`). The build number is the commit count, set at build time.
- [CHANGELOG.md](../CHANGELOG.md) and release notes are generated from PR titles by
  git-cliff (`cliff.toml`) — which is why PR titles must be Conventional Commits.
  Only `feat`, `fix`, `perf`, `security` and `refactor` reach users' eyes.

## Cutting a release

1. **Prepare on a branch** from `development`:
   ```bash
   git switch -c chore/release-0.2.0
   make version V=0.2.0
   make changelog V=0.2.0
   ```
   PR titled `chore(release): v0.2.0` into `development`; squash-merge.
2. **Release PR** from `development` into `main`, titled `chore(release): v0.2.0`.
   It merges with a **merge commit** (the ruleset allows nothing else on `main`).
3. **The Release workflow** builds a universal app, signs, notarizes, packages a DMG
   and a zip, and opens a **draft** GitHub Release with notes and SHA-256 checksums.
4. **Review the draft** — download the DMG, open it on a clean Mac if you can — then
   **Publish**. Publishing creates the `v0.2.0` tag.
5. **Homebrew**: bump the cask (below).

`make package` runs step 3's build locally (unsigned) into `build/release/`. PRs that
touch the pipeline run it as a dry run; *Actions → Release → Run workflow* does a
full dry run, including notarization when the secrets exist.

## Signing and notarization

Danny ships outside the Mac App Store, signed with a **Developer ID** and
**notarized** by Apple (ADR-010), using a Developer ID certificate and an App Store
Connect API key from the [Apple Developer Program](https://developer.apple.com/programs/).
Without them the pipeline still runs: releases are **ad-hoc signed and not
notarized**, and the release notes say so.

To turn signing on, add these repository secrets (*Settings → Secrets and variables →
Actions*). The workflow picks them up automatically; nothing else changes.

| Secret | What |
|---|---|
| `DEVELOPER_ID_P12_BASE64` | "Developer ID Application" certificate + private key, exported from Keychain Access as .p12, then `base64 -i cert.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | the password chosen when exporting the .p12 |
| `NOTARY_KEY_P8_BASE64` | App Store Connect API key (*Users and Access → Integrations*, role Developer), `base64 -i AuthKey_XXXX.p8` |
| `NOTARY_KEY_ID` | that key's ID |
| `NOTARY_ISSUER_ID` | the issuer ID shown above the keys list |

Everything is hardened-runtime signed, inside out: the bundled `yt-dlp`, `ffmpeg` and
`ffprobe` first (with `scripts/helper.entitlements`, because yt-dlp is a PyInstaller build
that loads its own Python libraries), then the app, then the DMG. With the notary key as
well, the app and the DMG are notarized and stapled, so they open offline.

## Bundled tools

`scripts/fetch-dependencies.sh` fills `Resources/bin`, which ships as
`Danny.app/Contents/Resources/bin`:

- **yt-dlp** — the pinned universal release, verified against yt-dlp's published checksums.
- **ffmpeg and ffprobe** — built from the pinned source by `scripts/build-ffmpeg.sh`:
  universal, LGPL only, and only the parts yt-dlp uses (ADR-013). A build takes a
  couple of minutes; CI caches it by the script's hash. Every build, cached or not,
  must pass `scripts/check-ffmpeg.sh`, which runs yt-dlp's ffmpeg commands on
  `Tests/Fixtures/media`. Their license texts and source go in `bin/licenses`.

Bumping a version is its own PR: change the version and checksum, then `make package`.
When yt-dlp starts asking ffmpeg for something new, add it to `build-ffmpeg.sh` and a
case to `check-ffmpeg.sh` in the same PR.

## Installing an unsigned build

Linked from the notes of every unsigned release.

1. Open the DMG and drag Danny to Applications.
2. Open Danny. macOS says it can't verify the developer — click **Done**.
3. Open **System Settings → Privacy & Security**, scroll to *Security*, and click
   **Open Anyway** next to the Danny message. Confirm with your password or Touch ID.

Only needed once per installed version. (Right-click → Open no longer skips the check
on current macOS.) Terminal alternative:
`xattr -dr com.apple.quarantine /Applications/Danny.app`.

Checksums for every file are in `SHA256SUMS.txt` on the release:
`shasum -a 256 -c SHA256SUMS.txt`.

## Homebrew

**Phase 1 — our own tap** (can start at the first release):

- A public repo `orpheus-ui/homebrew-tap` with `Casks/danny.rb`; users run
  `brew install --cask orpheus-ui/tap/danny`.
- The cask points at the release zip, pins its SHA-256, and declares
  `depends_on macos: ">= :tahoe"`, `auto_updates true` (once Sparkle lands), and a
  `zap` stanza for `~/Library/Application Support/Danny` and the preferences file.
- After each published release, the Release workflow bumps the cask (version + hash)
  with a token scoped to the tap repo — added once the tap exists.
- Unsigned builds still meet Gatekeeper after a Homebrew install; Homebrew has
  dropped its old `--no-quarantine` escape hatch.

**Phase 2 — the official `homebrew/cask`** (`brew install --cask danny`): needs a
notarized app (Homebrew's official casks must pass Gatekeeper) and a project notable
enough to meet their acceptance criteria (stars/forks/watchers). Once accepted,
Homebrew's autobump updates it and the tap cask is retired.

## Auto-updates (Sparkle) — planned

In-app updates use [Sparkle](https://sparkle-project.org): the app reads an
`appcast.xml` feed (published with each release), downloads the zip, verifies its
EdDSA signature, and installs it. It works for unsigned builds too, but without a
stable Developer ID signature macOS forgets per-app permissions after each update.

One-time setup: generate the EdDSA key pair with Sparkle's
`generate_keys` (stored in the login Keychain), put the **public** key in the app,
export the **private** key into the `SPARKLE_PRIVATE_KEY` secret, and keep a backup —
losing it means existing installs can't verify future updates.
