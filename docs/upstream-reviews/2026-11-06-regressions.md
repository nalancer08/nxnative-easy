# Baseline/candidate checks — 2026-11-06

Baseline: `27755119`; candidate runtime: `3e46c308`. Final changes after this candidate affect tests, engine lookup and documentation only.

## regress-report-final2/report.md

## regress.py check (full): PASS

Baseline `27755119` 277551191079, candidate `3e46c3087ed2c0edebe6a0cef630beeedf92b6e1` 3e46c3087ed2; Apple M2 Max, macOS 27.2, Xcode 27.2; 256.5 s

| game | status | shaders (base → cand) | newly failing | newly building | changed MSL | interface (new / known) | boot | fps p50 | frame p99 ms | peak MB | prepare s | new RED |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Dread `010093801237C000` | **PASS** | 1010/1010 → 1010/1010 | 0 | 0 | 0 | 0 / 0 | ok | 60.0 → 60.0 | 24.27 → 19.68 | 2426 → 2466 | None → None | 0 |

### Dread `010093801237C000`: PASS
  - screenshots (s: dHash bits / RGB diff / baseline noise): 110: 1/0.28/0
  - baseline: exit None, first frame 5.1 s, max frame 6892, reached True, prepare None s, prebuild 7.5 s (659 built, 0 failed), fps 60.0, p50/p99 16.75/24.27 ms, peak 2426 MB, busy Mac
  - candidate: exit None, first frame 4.6 s, max frame 6924, reached True, prepare None s, prebuild 6.7 s (659 built, 0 failed), fps 60.0, p50/p99 16.7/19.68 ms, peak 2466 MB, busy Mac
  - time: chain 1.4 s, smoke 254.9 s


## regress-report-final/report.md

## regress.py check (full): ERROR

Baseline `27755119` 277551191079, candidate `3e46c3087ed2c0edebe6a0cef630beeedf92b6e1` 3e46c3087ed2; Apple M2 Max, macOS 27.2, Xcode 27.2; 363.3 s

| game | status | shaders (base → cand) | newly failing | newly building | changed MSL | interface (new / known) | boot | fps p50 | frame p99 ms | peak MB | prepare s | new RED |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Dread `010093801237C000` | **ERROR** | 1010/1010 → 1010/1010 | 0 | 0 | 0 | 0 / 0 | – | – | – | – | – | – |
| LinksAwakening `01006BB00C6F0000` | **CHANGED** | 9698/9698 → 9698/9698 | 0 | 0 | 1 | 0 / 0 | ok | 59.7 → 59.8 | 20.78 → 20.77 | 1557 → 1543 | None → None | 0 |

### Dread `010093801237C000`: ERROR
- ERROR: TypeError: expected str, bytes or os.PathLike object, not NoneType
  - time: chain 31.3 s

### LinksAwakening `01006BB00C6F0000`: CHANGED
- CHANGED: 1 shaders changed (MSL 1, reflection 1, variants 1)
- CHANGED: screenshot at 50 s moved (RGB 10.54)
  - changed shaders: `bd619b15fcd2a711`
  - screenshots (s: dHash bits / RGB diff / baseline noise): 50: 9/10.54/0, 110: 0/0.11/0
  - baseline: exit None, first frame 2.0 s, max frame 7004, reached True, prepare None s, prebuild 163.5 s (17742 built, 0 failed), fps 59.7, p50/p99 16.61/20.78 ms, peak 1557 MB, busy Mac
  - candidate: exit None, first frame 1.8 s, max frame 7061, reached True, prepare None s, prebuild 171.1 s (17742 built, 0 failed), fps 59.8, p50/p99 16.56/20.77 ms, peak 1543 MB, busy Mac
  - time: chain 33.1 s, smoke 291.8 s


## Interpretation

Dread passes its no-input 120-second title route. The first early-input route compared different intro pages due to compilation load; both shader translations were identical. An intermediate retry used None instead of an empty string for keys and was corrected. Zelda passes with one changed shader and an allowed early-image color difference. All 1,010 Dread and 9,698 Zelda shaders compile on both revisions; zero new shader, interface or RED-kind failures. Zelda builds all 17,742 pipeline bases. Synthetic fresh saves only; measured frame rates on a busy machine are not controlled performance evidence.
