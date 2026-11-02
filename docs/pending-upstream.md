# Pending upstream review

Pinned head: `65501fbbaf8526f7aab0a1edd028135888590f8e`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: dm/host/Makefile

```text
65501fbb AV1 movies decode with dav1d where VideoToolbox has no AV1 decoder
bd41cf77 dav1d 1.5.4 vendored: the arm64 sources, unmodified, for AV1 movies where VideoToolbox has none
fefb16d1 Primitive ID pipelines: a GPU test, and their pairs left out of the prebuild and the offline archive
694ea914 Loader: the image the game's module sections are read from can be set (#729)
fa4c3566 Front ends: an app that hosts the game view can draw the prepare step's progress itself (#742)
```

Follow docs/agents/07-upstream-maintenance.md before integrating. This workflow never advances integrated_head, bumps releases, signs, installs or merges the PR.
