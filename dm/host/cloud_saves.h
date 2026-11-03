// Optional, append-only save continuity. UI calls run before gameplay only.
#pragma once
// Returns allocated JSON (free with free()); failures leave local saves intact.
char *nxe_cloud_command(const char *command, const char *argument);
// Successful game commits only enqueue work. Both committed trees are cloned
// under the filesystem's locks, never the mutable .work trees.
void nxe_cloud_committed(void);
// Requests a checkpoint and calls done once all coalesced workers finish.
// iOS uses this to end its finite background execution lease promptly.
void nxe_cloud_flush(void (*done)(void *), void *context);
int dm_fs_clone_save_pair(const char *save, const char *into);
