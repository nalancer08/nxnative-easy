## regress.py check (full): CHANGED

Baseline `c20bf0e0` c20bf0e05bdd, candidate `93163ff5` 93163ff5f409; Apple M2 Max, macOS 27.2, Xcode 27.2; 1466.4 s

| game | status | shaders (base → cand) | newly failing | newly building | changed MSL | interface (new / known) | boot | fps p50 | frame p99 ms | peak MB | prepare s | new RED |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Dread `010093801237C000` | **CHANGED** | 1010/1010 → 1010/1010 | 0 | 0 | 813 | 0 / 0 | ok | 59.6 → 59.7 | 20.77 → 20.64 | 2650 → 2609 | None → None | 0 |
| LinksAwakening `01006BB00C6F0000` | **CHANGED** | 9698/9698 → 9698/9698 | 0 | 0 | 6594 | 0 / 0 | ok | 59.9 → 59.9 | 20.18 → 20.27 | 1554 → 1557 | None → None | 0 |

### Dread `010093801237C000`: CHANGED
- CHANGED: 1010 shaders changed (MSL 813, reflection 1010, variants 992)
  - changed shaders: `003b38fe9b3627ba`, `00500b94cf88443d`, `00516aa1e784d9e0`, `0076e7956282bfc5`, `0094ff5d3f9cc5d8`, `0095d8689baf5ec7`, `00c32c2411fbbe03`, `00e1833e9ac78892`, `00e453d026d2fc05`, `00fe118ffda2ee0c`, `01055d415502eaa6`, `012068e325b0b4c3`, `01a48390c89957a4`, `01bb2e2343daaa92`, `01c79a49c01ab882`, `02295512bae1fd1b`, `024d83528f550fbe`, `02503a8189808d47`, `02a939263d583ed5`, `035e6a2b6d644d19`, `0365c6f2bc598f38`, `0366b4fb9baa6bf0`, `03d7e7a2efac8a2f`, `03f12c555d184617`, `0459b351d841fc2b`, `045a54bb20e3750f`, `051c001a5ba37928`, `05251d2037611165`, `0558bceeac0c3e90`, `056049b870fd754f`, `05d7c93d306ce7b0`, `0664bf4cf905428d`, `0665288c892231e9`, `069b1843c4a4bb52`, `06e42c176f1875e6`, `070e1d7aaac06775`, `076d8c127a7f0526`, `07c8fcc6d480f88f`, `080f05eeb6d4ac45`, `08163380d49d7720` …
  - screenshots (s: dHash bits / RGB diff / baseline noise): 50: 0/0.01/0, 110: 1/0.17/0
  - baseline: exit None, first frame 4.6 s, max frame 6802, reached True, prepare None s, prebuild 6.9 s (659 built, 0 failed), fps 59.6, p50/p99 16.67/20.77 ms, peak 2650 MB, busy Mac
  - candidate: exit None, first frame 4.8 s, max frame 6815, reached True, prepare None s, prebuild 9.2 s (659 built, 0 failed), fps 59.7, p50/p99 16.67/20.64 ms, peak 2609 MB, busy Mac
  - time: chain 1.3 s, smoke 129.8 s

### LinksAwakening `01006BB00C6F0000`: CHANGED
- CHANGED: 9697 shaders changed (MSL 6594, reflection 9672, variants 8903)
  - changed shaders: `00008ab75998b65a`, `000be95364b95b90`, `001208e4805129e4`, `0013763043317a10`, `001479022668372e`, `0016eab24b31cd07`, `00269b17edce89db`, `00340575473de03f`, `003ae6cb51c2cf9f`, `003ccb11417c8bb5`, `003e55f780cd04d0`, `004680c41863d20c`, `004ea7bd33889037`, `00516767bc664f26`, `00522951a00e378f`, `0084ae3fa0f8491e`, `008d5f1f7f5a5cb7`, `009a09e75309c4b1`, `009f5c007e366d36`, `00a40f903bab0198`, `00a61ad094a20c1b`, `00a8ce89eabc72ac`, `00ab46fe80fee869`, `00afc46dd25b5e84`, `00b4d2b2a923c736`, `00b8ac203c039320`, `00b96e26fb756c6d`, `00c1b1fa40c6a005`, `00c1c038a2116eda`, `00c4a1f5c22911f3`, `00c8eaba05bef398`, `00cc11b62e6e608c`, `00d101abb784e999`, `00d22ae54723144b`, `00dca0fd2788e22e`, `00e15b40e62eb660`, `00e36158e416ad8b`, `00eb4fc414da26b5`, `00edfb6ce41feb06`, `00fbe95024833aae` …
  - screenshots (s: dHash bits / RGB diff / baseline noise): 50: 6/2.9/0, 110: 0/0.27/0
  - baseline: exit None, first frame 1.3 s, max frame 7078, reached True, prepare None s, prebuild 209.5 s (17742 built, 0 failed), fps 59.9, p50/p99 16.62/20.18 ms, peak 1554 MB, busy Mac
  - candidate: exit None, first frame 1.6 s, max frame 7094, reached True, prepare None s, prebuild 197.7 s (17742 built, 0 failed), fps 59.9, p50/p99 16.58/20.27 ms, peak 1557 MB, busy Mac
  - time: chain 686.7 s, smoke 648.4 s
