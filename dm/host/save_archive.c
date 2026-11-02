// Archive primitives adapted from seedds/nxnative 4a2a81a6 (MIT); no upstream synchronization or date-based conflict policy. Plain C on system calls and CommonCrypto only, so the Mac launcher links it as the host does (dm/mac/pack_app.py).
// A packed save (<folder>/<title ID>/save.dmsync), little-endian:
//   header  "DMSYNC1\n", u32 version (1), u32 entries, 32 hex digits of the hash, i64 saved, char title[24], char device[64]
//   entry   u8 type (1 folder, 2 file), u8 0, u16 path length, u16 guest-name length, u16 0, u64 size, i64 mtime; the path (save/... or save_device/...), the guest name, the contents
//   end     "DMSYNCE\n", then the end of the file (a file cut off anywhere is refused)
// The hash runs over each entry's first 16 header bytes (not the date), its path, its guest name and its contents, in the order walk() visits them.
#include "save_archive.h"
#include <CommonCrypto/CommonDigest.h>
#include <TargetConditionals.h>
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/clonefile.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/xattr.h>
#include <time.h>
#include <unistd.h>

#define SLOG(...) do { fprintf(stderr, "[dm] save sync: " __VA_ARGS__); fputc('\n', stderr); } while (0)
#define SRED(...) do { fprintf(stderr, "[dm] [RED] save sync: " __VA_ARGS__); fputc('\n', stderr); } while (0)
#define GUEST_NAME "org.d2rmobile.guest-name"   // hle_fs.c FS_GUEST_NAME: a file's guest name when its host name had to differ (a case collision); part of the save
#define QUIET_MS 3000    // a game often commits several times in a row: the sender waits until it has been quiet this long
#define FETCH_MS 10000   // the longest the game waits at its first save mount for the cloud's copy (a download); then it plays on with this device's save
#define KEEP_BACKUPS 10  // backups kept of each side (local, cloud); older ones are removed when a new one is made
enum { HDR = 8 + 4 + 4 + SS_HASH + 8 + 24 + 64, ENT = 24, CHUNK = 1 << 16 };   // header bytes, entry header bytes, the copy buffer
static const char MAGIC[8] __attribute__((nonstring)) = "DMSYNC1\n", END[8] __attribute__((nonstring)) = "DMSYNCE\n";
static const char *const FOLDERS[2] = {"save", "save_device"};   // their names in a packed save; on disk DM_SAVE and DM_SAVE_device (hle_fs.c h_fs_MountDeviceSave)

// ---------- files ----------
static void folder_path(const char *save, int i, char *out, size_t n) { snprintf(out, n, i ? "%s_device" : "%s", save); }

static void free_names(char **v, size_t n) { for (size_t i = 0; i < n; i++) free(v[i]); free(v); }
static int by_name(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }
// A folder's names in byte order, without . and ..; -1 when it cannot be read
static int names_of(const char *dir, char ***out, size_t *count) {
    DIR *d = opendir(dir); if (!d) return -1;
    char **v = NULL; size_t n = 0, cap = 0; struct dirent *e; int r = 0;
    while (1) {
        errno = 0; e = readdir(d);
        if (!e) { if (errno) r = -1; break; }
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        if (n >= 100000) { r = -1; break; }
        if (n == cap) { char **w = realloc(v, (cap = cap ? cap * 2 : 16) * sizeof *v); if (!w) { r = -1; break; } v = w; }
        if (!(v[n] = strdup(e->d_name))) { r = -1; break; }
        n++;
    }
    if (closedir(d)) r = -1;
    if (r) { free_names(v, n); return -1; }
    if (n) qsort(v, n, sizeof *v, by_name);
    *out = v; *count = n; return 0;
}

static int mkdirs(const char *path) {   // mkdir -p
    char p[PATH_MAX]; if (snprintf(p, sizeof p, "%s", path) >= (int)sizeof p) return -1;
    for (char *s = p + 1; *s; s++) if (*s == '/') { *s = 0; mkdir(p, 0755); *s = '/'; }
    return mkdir(p, 0755) && errno != EEXIST ? -1 : 0;
}

static int rm_tree(const char *p) {   // rm -rf: 0 when nothing is left
    struct stat st; if (lstat(p, &st)) return errno == ENOENT ? 0 : -1;
    if (!S_ISDIR(st.st_mode)) return unlink(p);
    char **v; size_t n; if (names_of(p, &v, &n)) return -1;
    int r = 0;
    for (size_t i = 0; i < n; i++) { char c[PATH_MAX]; snprintf(c, sizeof c, "%s/%s", p, v[i]); if (rm_tree(c)) r = -1; }
    free_names(v, n);
    return rmdir(p) ? -1 : r;
}

// Anything in it but Finder's .DS_Store: an empty folder is no save (the host makes DM_SAVE at every mount, DM_SAVE_device at the device save's)
static int has_entries(const char *dir) {
    char **v; size_t n, k = 0; if (names_of(dir, &v, &n)) return 0;
    for (size_t i = 0; i < n; i++) k += strcmp(v[i], ".DS_Store") != 0;
    free_names(v, n); return k > 0;
}

typedef int (*visit_fn)(void *ctx, const char *abs, const char *rel, const struct stat *st);
// Every entry under abs, depth first, a folder before what it holds, names in byte order: the order that gives the same save the same hash on every device.
// Finder's .DS_Store is left out (a save folder someone opened in Finder is still the same save), and so are links, which the host never makes in a save
static int walk(const char *abs, const char *rel, visit_fn fn, void *ctx) {
    char **v; size_t n; if (names_of(abs, &v, &n)) return -1;
    int r = 0;
    for (size_t i = 0; i < n && !r; i++) {
        if (!strcmp(v[i], ".DS_Store")) continue;
        char a[PATH_MAX], p[PATH_MAX]; struct stat st;
        if (snprintf(a, sizeof a, "%s/%s", abs, v[i]) >= (int)sizeof a || snprintf(p, sizeof p, "%s/%s", rel, v[i]) >= (int)sizeof p || lstat(a, &st)) r = -1;
        else if (S_ISDIR(st.st_mode)) { if (!(r = fn(ctx, a, p, &st))) r = walk(a, p, fn, ctx); }
        else if (S_ISREG(st.st_mode)) r = fn(ctx, a, p, &st);
        else r = -1; // Refuse links/special files rather than silently omit progress.
    }
    free_names(v, n); return r;
}

static int write_all(int fd, const void *b, size_t n) {
    for (const char *p = b; n; ) { ssize_t k = write(fd, p, n); if (k < 0 && errno == EINTR) continue; if (k <= 0) return -1; p += k; n -= (size_t)k; }
    return 0;
}

static int copy_fd(int in, int out) {
    char *b = malloc(CHUNK); if (!b) return -1;
    ssize_t k; int r = 0;
    while ((k = read(in, b, CHUNK)) != 0) { if (k < 0) { if (errno == EINTR) continue; r = -1; break; } if (write_all(out, b, (size_t)k)) { r = -1; break; } }
    free(b); return r;
}

static void hex(const uint8_t *d, char *out) { for (int i = 0; i < SS_HASH / 2; i++) snprintf(out + 2 * i, 3, "%02x", d[i]); }

static void when(int64_t t, char *out, size_t n) {   // a save's time in the log
    time_t tt = (time_t)t; struct tm tm;
    if (!t || !localtime_r(&tt, &tm) || !strftime(out, n, "%Y-%m-%d %H:%M:%S", &tm)) snprintf(out, n, "unknown");
}

static void device_name(char *out, size_t n) {   // the model ("Mac16,1", "iPhone17,1"): which device a save came from, for the log
    char model[64] = ""; size_t len = sizeof model;
    if (sysctlbyname(TARGET_OS_OSX ? "hw.model" : "hw.machine", model, &len, NULL, 0)) model[0] = 0;
    snprintf(out, n, "%s", model[0] ? model : "unknown");
}

static void upper_title(const char *title, char *out, size_t n) {   // one spelling of the title ID in the cloud, whoever packed the app
    size_t i = 0; for (; title[i] && i + 1 < n; i++) out[i] = (char)toupper((unsigned char)title[i]);
    out[i] = 0;
}

// ---------- packing ----------
typedef struct { CC_SHA256_CTX sha; FILE *out; ss_meta *m; uint32_t entries; uint64_t bytes; uint8_t buf[CHUNK]; } packer;

static int pack_entry(void *c, const char *abs, const char *rel, const struct stat *st) {
    packer *k = c;
    char guest[1024]; ssize_t gl = getxattr(abs, GUEST_NAME, guest, sizeof guest, 0, XATTR_NOFOLLOW);
    if (gl < 0) { if (errno != ENOATTR) return -1; gl = 0; } // A failed metadata read must not silently change guest names.
    size_t pl = strlen(rel); int file = S_ISREG(st->st_mode);
    if (pl > UINT16_MAX || st->st_size > (256LL << 20)) return -1;
    uint8_t h[ENT] = {(uint8_t)(file ? 2 : 1)}; uint16_t pl16 = (uint16_t)pl, gl16 = (uint16_t)gl;
    uint64_t size = file ? (uint64_t)st->st_size : 0; int64_t mt = st->st_mtimespec.tv_sec;
    memcpy(h + 2, &pl16, 2); memcpy(h + 4, &gl16, 2); memcpy(h + 8, &size, 8); memcpy(h + 16, &mt, 8);
    CC_SHA256_Update(&k->sha, h, 16); CC_SHA256_Update(&k->sha, rel, (CC_LONG)pl); CC_SHA256_Update(&k->sha, guest, (CC_LONG)gl);
    if (k->out && (fwrite(h, 1, ENT, k->out) != ENT || fwrite(rel, 1, pl, k->out) != pl || fwrite(guest, 1, (size_t)gl, k->out) != (size_t)gl)) return -1;
    if (++k->entries > 100000 || (k->bytes += size) > (256ULL << 20)) return -1;
    if (!file) return 0;
    int fd = open(abs, O_RDONLY | O_NOFOLLOW); if (fd < 0) return -1;
    uint64_t left = size; ssize_t got = 0;
    while (left && (got = read(fd, k->buf, left < CHUNK ? (size_t)left : CHUNK)) != 0) {
        if (got < 0) { if (errno == EINTR) continue; break; }
        CC_SHA256_Update(&k->sha, k->buf, (CC_LONG)got);
        if (k->out && fwrite(k->buf, 1, (size_t)got, k->out) != (size_t)got) break;
        left -= (uint64_t)got;
    }
    close(fd);
    if (left) return -1;   // a failed read, or a file shorter than its size (the save is a clone no Commit touches, so not one being written)
    k->m->files++;
    if (mt > k->m->saved) k->m->saved = mt;
    return 0;
}

static int pack_save(const char *save, packer *k) {
    CC_SHA256_Init(&k->sha);
    for (int i = 0; i < 2; i++) {
        char dir[PATH_MAX]; folder_path(save, i, dir, sizeof dir);
        struct stat st;
        if (lstat(dir, &st)) { if (errno == ENOENT) continue; return -1; }
        if (!S_ISDIR(st.st_mode)) return -1;
        if (walk(dir, FOLDERS[i], pack_entry, k)) return -1;
    }
    uint8_t d[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(d, &k->sha); hex(d, k->m->hash);
    if (!k->m->files) k->m->hash[0] = 0;   // no save: no hash, so that "nothing here" compares as nothing
    return 0;
}

int ss_scan(const char *save, ss_meta *m) {
    memset(m, 0, sizeof *m);
    packer *k = calloc(1, sizeof *k); if (!k) return -1;
    k->m = m; int r = pack_save(save, k);
    free(k); return r;
}

int ss_pack(const char *save, const char *title, const char *out, ss_meta *m) {
    memset(m, 0, sizeof *m);
    upper_title(title, m->title, sizeof m->title); device_name(m->device, sizeof m->device);
    packer *k = calloc(1, sizeof *k); if (!k) return -1;
    k->m = m; int r = -1;
    uint8_t hdr[HDR] = {0}; uint32_t version = 1;
    if (!(k->out = fopen(out, "wb")) || fwrite(hdr, 1, HDR, k->out) != HDR || pack_save(save, k) || fwrite(END, 1, sizeof END, k->out) != sizeof END) goto done;
    memcpy(hdr, MAGIC, 8); memcpy(hdr + 8, &version, 4); memcpy(hdr + 12, &k->entries, 4); memcpy(hdr + 16, m->hash, strlen(m->hash));
    memcpy(hdr + 48, &m->saved, 8); memcpy(hdr + 56, m->title, strlen(m->title)); memcpy(hdr + 80, m->device, strlen(m->device));
    if (fseeko(k->out, 0, SEEK_SET) || fwrite(hdr, 1, HDR, k->out) != HDR || fflush(k->out) || fsync(fileno(k->out))) goto done;
    r = 0;
done:
    if (k->out && fclose(k->out)) r = -1;
    if (r) unlink(out);
    free(k); return r;
}

// A path in a packed save: under save/ or save_device/, with no empty, . or .. part (a damaged file must not write outside `into`)
static int path_ok(const char *p) {
    if (strncmp(p, "save/", 5) && strncmp(p, "save_device/", 12)) return 0;
    for (const char *s = p;; ) {
        const char *e = strchr(s, '/'); size_t n = e ? (size_t)(e - s) : strlen(s);
        if (!n || (n == 1 && s[0] == '.') || (n == 2 && s[0] == '.' && s[1] == '.')) return 0;
        if (!e) return 1;
        s = e + 1;
    }
}

int ss_read(const char *bundle, const char *into, ss_meta *m) {
    memset(m, 0, sizeof *m);
    FILE *f = fopen(bundle, "rb"); if (!f) return -1;
    uint8_t *buf = malloc(CHUNK), hdr[HDR], h[ENT], end[sizeof END], d[CC_SHA256_DIGEST_LENGTH];
    char want[SS_HASH + 1] = "", path[PATH_MAX], guest[1024], out[PATH_MAX];
    uint32_t version, n; int r = -1, fd = -1;
    CC_SHA256_CTX sha; CC_SHA256_Init(&sha);
    if (!buf || fread(hdr, 1, HDR, f) != HDR || memcmp(hdr, MAGIC, 8)) goto done;
    memcpy(&version, hdr + 8, 4); memcpy(&n, hdr + 12, 4);
    if (version != 1 || n > 100000) goto done;
    memcpy(want, hdr + 16, SS_HASH); memcpy(&m->saved, hdr + 48, 8); memcpy(m->title, hdr + 56, 23); memcpy(m->device, hdr + 80, 63);
    for (uint32_t i = 0; i < n; i++) {
        uint16_t pl, gl; uint64_t size; int64_t mt;
        if (fread(h, 1, ENT, f) != ENT) goto done;
        memcpy(&pl, h + 2, 2); memcpy(&gl, h + 4, 2); memcpy(&size, h + 8, 8); memcpy(&mt, h + 16, 8);
        if (size > (256ULL << 20)) goto done;
        if ((h[0] != 1 && h[0] != 2) || !pl || pl >= sizeof path || gl > sizeof guest || (h[0] == 1 && size)) goto done;
        if (fread(path, 1, pl, f) != pl || fread(guest, 1, gl, f) != gl) goto done;
        path[pl] = 0;
        if (strlen(path) != pl || !path_ok(path)) goto done;
        CC_SHA256_Update(&sha, h, 16); CC_SHA256_Update(&sha, path, pl); CC_SHA256_Update(&sha, guest, gl);
        if (into) {
            if (snprintf(out, sizeof out, "%s/%s", into, path) >= (int)sizeof out) goto done;
            if (h[0] == 1) { if (mkdirs(out)) goto done; }
            else {
                *strrchr(out, '/') = 0; int made = mkdirs(out); out[strlen(out)] = '/';
                if (made || (fd = open(out, O_WRONLY | O_CREAT | O_EXCL, 0644)) < 0) goto done;
            }
            if (gl && setxattr(out, GUEST_NAME, guest, gl, 0, XATTR_NOFOLLOW)) goto done;
        }
        for (uint64_t left = size; left; ) {
            size_t k = left < CHUNK ? (size_t)left : CHUNK;
            if (fread(buf, 1, k, f) != k) goto done;
            CC_SHA256_Update(&sha, buf, (CC_LONG)k);
            if (fd >= 0 && write_all(fd, buf, k)) goto done;
            left -= k;
        }
        if (fd >= 0) {   // the file's own date back: the newest one is the save's age when two changed saves are compared (ss_decide), not the time of the copy
            struct timespec t[2] = {{(time_t)mt, 0}, {(time_t)mt, 0}}; futimens(fd, t);
            int bad = fsync(fd); if (close(fd)) bad = -1; fd = -1; if (bad) goto done;
        }
        if (h[0] == 2) m->files++;
    }
    if (fread(end, 1, sizeof end, f) != sizeof end || memcmp(end, END, sizeof end) || fgetc(f) != EOF) goto done;
    CC_SHA256_Final(d, &sha); hex(d, m->hash);
    if (!m->files) m->hash[0] = 0;
    if (strcmp(m->hash, want)) goto done;
    r = 0;
done:
    if (fd >= 0) close(fd);
    free(buf); fclose(f);
    if (r) m->files = 0, m->hash[0] = 0;
    return r;
}
