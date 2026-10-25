# Changelog

What changed in each Danny release. Generated from pull request titles by
[git-cliff](https://git-cliff.org) — see cliff.toml.
## 0.1.0 — 2026-10-25

### New

- Match the card to Figma and design its missing states (#69)
- Add a Clear Cache button for the web cache (#66)
- Verify yt-dlp updates against its release signature (#57)
- Block ads and trackers in Browser Capture (#58)
- Mint YouTube tokens so signed-in downloads keep full quality (#55)
- Select, remove and retry downloads from the keyboard (#54)
- Group the list into Active, Today and Earlier (#52)
- Put Settings in tabs (#51)
- Show progress and paste to download in the menu bar (#47)
- Name speed limits Full Speed, Balanced and Background (#46)
- Pause and resume downloads (#45)
- Download only on Wi-Fi and limit download speed (#44)
- Quick Look, double-click to open, and file actions on the Done bar (#43)
- Show download progress in the Dock and notify when a download finishes (#41)
- Save into a folder per site and name files by template (#40)
- Explain a failed download in a few words with the one action that can help (#39)
- Offer a copied link in a toast instead of adding it silently (#36)
- Use the macOS system proxy for downloads (#33)
- Keep the Mac awake while downloading (#34)
- Add links with ⌘V in the window and by drag and drop (#31)
- Check for a newer yt-dlp from Settings (#26)
- Download YouTube signed out first, signed in only when asked (#22)
- Bundle QuickJS-ng so yt-dlp can read YouTube's player (#20)
- Keep yt-dlp current, checked each time Danny opens (#19)
- Quality and format settings, with a picker on the card (#17)
- Sign in to sites so downloads work as the signed-in user (#16)
- **ui:** Title bar per Figma, one line with the window controls (#13)
- **ui:** One search field that finds and adds (#12)
- **ui:** Rebuild the progress bar with Metal dots and a passing light (#9)
- **ui:** Design tokens from Figma (#8)

### Fixed

- Read each yt-dlp's output on its own, and time out --version (#70)
- Retry downloads that asked for a sign-in once the sign-in window closes signed in (#67)
- Stop the progress light of a card that left the list (#61)
- Resume keeps the destination and format a download started with (#49)
- Save downloads in the chosen folder, not a Danny folder inside it (#24)
- Ask before downloading a video that is already in the folder (#23)
- Stop yt-dlp as soon as a download is removed (#21)
- Count a merged download once in the progress total (#18)
- Keep download progress between 0 and 100% (#15)
- **ui:** Match the bottom bar to Figma, with liquid glass buttons (#11)

### Faster and lighter

- Ease the progress bar at 30 fps and update progress once a second (#63)
- Redraw only the card whose download progressed, and store the list (#60)
- Download fragmented streams with 8 connections (#32)

### Under the hood

- **downloads:** Drop dead code in add and test the sign-in probe retry (#68)
- **sniffer:** Drop nonisolated from the web view delegates (#48)

