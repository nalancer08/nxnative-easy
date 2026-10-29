# Per-game options and disposable caches

A built Mac game's library detail shows **Mac game options**. Rows come from that
app's `Contents/Resources/dm/launcher.json`, schema 1, using upstream's choices,
toggles, ranges and dependent rows. Unsupported schemas/kinds do not create
invented options. The settings affect the next launch, not a currently running
game. iPhone/iPad settings remain in that game's own launcher on the device.

Only validated values that differ from a tested default are saved, under
`launcher.<DM_VARIABLE>` in the exact game's bundle preferences domain. Reset
removes only those offered setting keys. Rebuilds keep the domain and choices.
Environment variables and `env.txt` retain their documented priority. This does
not edit game files, save folders or the signed game app.

**Free build storage** first previews exact byte totals. It lists only
`<TitleID>_build/shader/cache` and `<TitleID>_build/tmp` when they contain no links,
special files or protected game/key/save/output content. Nothing is selected by
default. The player must select entries and confirm their deletion.

Before deletion, the tool rechecks the entire preview digest, root inode/device
and path boundaries and holds the same checkout/game lock as game preparation.
Descriptor-relative deletion never follows links. A changed preview, protected
file or active build stops cleanup. Original archives, complete apps, IPAs,
RomFS/ExeFS, keys, save roots, exported ZIPs and source/tools are excluded. The
next build can take longer after deleting caches. No migration or automatic
cleanup is performed while updating the desktop app.
