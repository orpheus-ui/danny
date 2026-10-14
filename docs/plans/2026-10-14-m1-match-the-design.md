# M1 — Match the design

| Task | Status | PR |
|---|---|---|
| tokens — Figma colors, gradients, radii and type into `D` | not started | — |
| snapshots — snapshot tests for every card state | not started | — |
| progress-bar — Metal shader, two-tone label, eased progress | not started | — |
| card — full-bleed thumbnail, scrim, title/meta/actions | not started | — |
| bars — title bar and bottom bar | not started | — |
| states — Queued, Fetching, Merging, Paused, Failed, empty list | not started | — |
| debt — clipboard timer, list re-renders, `visibleItems` cache | not started | — |

The Figma file is the spec: main window `1:127` (640×487), cards under `1:139`,
title bar `1:133`, bottom bar `2:717`. Each UI task compares the build with its
frame before the PR opens, and the PR shows before/after screenshots.

## Order and why

1. **tokens** first, so every later PR uses `D` instead of literals. Values come
   from the Figma variables and styles; anything Figma has no variable for is
   named after its role (`D.cardScrim`, not `D.black92`). No visual change beyond
   values that were already wrong.
2. **snapshots** next, so the redesign has a baseline to diff against. One
   reference image per `ItemStatus` × representative content (long title, no
   thumbnail, unknown size), rendered at a fixed size and scale so CI and laptops
   agree. Test-only dependency; the choice (a library or `ImageRenderer` plus a
   small comparer) is recorded as an ADR in the same PR.
3. **progress-bar** — the most visible piece and the riskiest for resource use:
   - Fill and halftone dot texture drawn by a `[[stitchable]]` Metal shader
     through SwiftUI's `layerEffect`; no per-frame CPU drawing.
   - The label is centered and drawn twice, clipped at the fill's edge, so it
     reads in two tones over fill and track at any percentage.
   - Progress eases toward each new value instead of jumping per yt-dlp line.
   - The indeterminate (Fetching, Merging) animation runs at ≤30 fps, stops when
     the window is hidden or occluded, and replaces the 20 fps `TimelineView` in
     `ProcessingCapsule`. Measured with `/perf-check` before and after.
4. **card**, then **bars** — layout, type and actions per Figma.
5. **states** — the frames Figma doesn't have yet are drawn in the same language
   (glass, purple accent, halftone, bold white labels), reviewed as images, and
   added to the Figma file once approved, so Figma stays the one spec. Then
   they're built. Paused is the visual state only; pausing the engine
   lands with the core work in M2.
6. **debt** — the resource items in `backlog.md` that touch the UI. The list
   re-render fix may come earlier if the progress bar work needs it.

## Done when

- Every card state has a snapshot test, and each matches its Figma frame
  (including the frames added for states the design didn't have).
- Idle Danny uses 0% CPU and the progress bar stays within the budget in
  `engineering.md` (ADR-008).
- The backlog's UI resource items are closed.

## Open

- The chevron next to the window title in Figma: what it switches is undecided,
  so it isn't built until it is.
