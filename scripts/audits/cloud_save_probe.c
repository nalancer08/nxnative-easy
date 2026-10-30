// Isolated synthetic audit harness. Never reads a real save or iCloud directory.
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

static int swaps;
static int fail_second_swap(const char *a, const char *b, unsigned flags) {
    if (++swaps == 2) { errno = EIO; return -1; }
    return renamex_np(a, b, flags);
}

// Include the pinned implementation to exercise its actual internal decisions.
#define renamex_np fail_second_swap
#include "save_sync.c"
#undef renamex_np

static void put(const char *path, const char *value) {
    FILE *f = fopen(path, "wb");
    if (!f) abort();
    if (fwrite(value, 1, strlen(value), f) != strlen(value)) abort();
    if (fclose(f)) abort();
}

static int contains(const char *path, const char *value) {
    char data[64] = {0};
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    fread(data, 1, sizeof(data) - 1, f);
    fclose(f);
    return !strcmp(data, value);
}

int main(int argc, char **argv) {
    if (argc != 2) return 9;
    char root[PATH_MAX];
    snprintf(root, sizeof root, "%s/fixtures.XXXXXX", argv[1]);
    if (!mkdtemp(root)) return 9;

    char local[PATH_MAX], remote[PATH_MAX], p[PATH_MAX], q[PATH_MAX];
    char bundle[PATH_MAX], kept[PATH_MAX];
    ss_meta meta;
    snprintf(local, sizeof local, "%s/local/save", root);
    snprintf(remote, sizeof remote, "%s/remote/save", root);
    if (mkdirs(local) || mkdirs(remote)) return 8;
    snprintf(p, sizeof p, "%s_device", local);
    if (mkdirs(p)) return 8;
    snprintf(p, sizeof p, "%s_device", remote);
    if (mkdirs(p)) return 8;
    snprintf(p, sizeof p, "%s/game.dat", local); put(p, "LOCAL");
    snprintf(p, sizeof p, "%s_device/device.dat", local); put(p, "LOCAL_DEVICE");
    snprintf(p, sizeof p, "%s/game.dat", remote); put(p, "REMOTE");
    snprintf(p, sizeof p, "%s_device/device.dat", remote); put(p, "REMOTE_DEVICE");
    snprintf(bundle, sizeof bundle, "%s/snapshot.dmsync", root);
    if (ss_pack(remote, "010093801237C000", bundle, &meta)) return 8;

    int rc = pull(local, bundle, &meta, kept, sizeof kept);
    snprintf(p, sizeof p, "%s/game.dat", local);
    snprintf(q, sizeof q, "%s_device/device.dat", local);
    int mixed = rc < 0 && contains(p, "REMOTE") && contains(q, "LOCAL_DEVICE");
    printf("Injected second-folder swap failure: rejected=%d, mixed local save=%d\n", rc < 0, mixed);

    // Both sides diverge from the last synchronized revision; the local one is older.
    char conflict[PATH_MAX], cloud[PATH_MAX], packed[PATH_MAX];
    snprintf(conflict, sizeof conflict, "%s/conflict/save", root);
    if (mkdirs(conflict)) return 7;
    snprintf(p, sizeof p, "%s/game.dat", conflict);
    put(p, "COMMON");
    if (ss_scan(conflict, &meta)) return 7;
    write_base(conflict, meta.hash);
    put(p, "OLDER_LOCAL");
    struct timespec old[2] = {{1000000000, 0}, {1000000000, 0}};
    if (utimensat(AT_FDCWD, p, old, 0)) return 7;
    snprintf(p, sizeof p, "%s/game.dat", remote);
    put(p, "NEWER_REMOTE");
    struct timespec newer[2] = {{2000000000, 0}, {2000000000, 0}};
    if (utimensat(AT_FDCWD, p, newer, 0)) return 7;
    snprintf(cloud, sizeof cloud, "%s/cloud", root);
    if (mkdirs(cloud)) return 7;
    snprintf(packed, sizeof packed, "%s/save.dmsync", cloud);
    if (ss_pack(remote, "010093801237C000", packed, &meta)) return 7;

    int sent = send_save(conflict, "010093801237C000", packed);
    if (ss_read(packed, NULL, &meta)) return 7;
    ss_meta local_meta;
    if (ss_scan(conflict, &local_meta)) return 7;
    int overwrite = sent && !strcmp(meta.hash, local_meta.hash) && meta.saved == 1000000000;
    printf("Divergent older local upload: succeeded=%d, replaced newer cloud=%d\n", sent, overwrite);
    if (rm_tree(root)) return 6;
    return 0;
}
