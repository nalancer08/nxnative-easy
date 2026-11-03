// nxnative Easy save continuity. Active saves stay local; the chosen iCloud
// folder contains immutable SHA-256 addressed revisions, never a mutable latest.
// Timestamps describe a revision; ancestry, not clocks, determines continuity.
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <TargetConditionals.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include "cloud_saves.h"
#include "save_archive.h"

static NSFileManager *fm;
static NSString *save, *vault, *compat, *title, *device, *cloud, *gameVersion;
static dispatch_queue_t queue;
static dispatch_group_t workers;
static BOOL playing, localSafe, initialized;
static int lease = -1;
static const unsigned long long MAX_REVISION = 270ULL << 20;
static NSString *const suffix = @".nxsave";
static void fail(NSString *message) { @throw [NSException exceptionWithName:@"SaveContinuity" reason:message userInfo:nil]; }
static void need(BOOL ok, NSString *message) { if (!ok) fail(message); }
static NSString *at(NSString *a, NSString *b) { return [a stringByAppendingPathComponent:b]; }
static BOOL exists(NSString *p) { if (!p) return NO; return [fm fileExistsAtPath:p]; }
static BOOL hexID(NSString *s) {
    return [s isKindOfClass:NSString.class] && s.length == 64 &&
        [s rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location == NSNotFound;
}
static void plain(NSString *p, BOOL directory) {
    struct stat st;
    need(!lstat(p.fileSystemRepresentation, &st) && (directory ? S_ISDIR(st.st_mode) : S_ISREG(st.st_mode)), @"A save path is unavailable or is a link. No restore was performed.");
}
static void mkdirs(NSString *p) {
    need([fm createDirectoryAtPath:p withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil], @"Not enough space or permission to create save history.");
    plain(p, YES);
}
static void syncDir(NSString *p) {
    int fd = open(p.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    need(fd >= 0, @"Cannot open save history for a durable write.");
    int err = fsync(fd); close(fd);
    need(!err, @"Save history could not be committed to disk.");
}
static void atomicData(NSData *data, NSString *p) {
    need(data != nil && data.length > 0 && data.length <= MAX_REVISION, @"Snapshot data is unavailable or too large. Nothing was replaced.");
    NSString *tmp = [p stringByAppendingFormat:@".%@.partial", NSUUID.UUID.UUIDString];
    int fd = open(tmp.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    need(fd >= 0, @"Cannot create a save snapshot. Check free space.");
    const char *bytes = data.bytes; NSUInteger left = data.length; int err = 0;
    while (left) {
        ssize_t n;
#ifdef NXE_CLOUD_TESTING
        const char *failure = getenv("NXE_TEST_CLOUD_FAIL");
        if (failure && !strcmp(failure, "snapshot-write")) { errno = ENOSPC; n = -1; }
        else
#endif
        n = write(fd, bytes, left); if (n < 0 && errno == EINTR) continue; if (n <= 0) { err = 1; break; } bytes += n; left -= n; }
    if (fsync(fd)) err = 1;
    if (close(fd)) err = 1;
    if (!err && rename(tmp.fileSystemRepresentation, p.fileSystemRepresentation)) err = 1;
    if (err) { unlink(tmp.fileSystemRepresentation); fail(@"Snapshot write failed. Your local save was kept."); }
    syncDir(p.stringByDeletingLastPathComponent);
}
static NSData *json(id object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingSortedKeys error:nil];
    need(data != nil, @"Invalid save metadata."); return data;
}
static NSDictionary *dictionary(NSData *data) {
    id d = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    need([d isKindOfClass:NSDictionary.class], @"Save metadata is incomplete or damaged."); return d;
}
static NSString *digest(NSData *data) {
    unsigned char hash[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    NSMutableString *s = [NSMutableString string]; for (int i = 0; i < sizeof hash; i++) [s appendFormat:@"%02x", hash[i]]; return s;
}
static NSString *revisionPath(NSString *ID) { need(hexID(ID), @"Invalid revision ID."); return at(at(vault, @"revisions"), [ID stringByAppendingString:suffix]); }
static NSDictionary *state(void) {
    NSString *p = at(vault, @"state.json");
    return exists(p) ? dictionary([NSData dataWithContentsOfFile:p]) : @{};
}
static void base(NSString *ID, NSString *hash) { atomicData(json(@{@"base": ID, @"hash": hash, @"folder": cloud ?: @""}), at(vault, @"state.json")); }
static NSString *scan(NSString *p) { ss_meta m; need(ss_scan(p.fileSystemRepresentation, &m) == 0, @"Cannot read the complete local save. Nothing was replaced."); return @(m.hash); }
static NSDictionary *readRevision(NSString *path, NSString *ID, NSString *into) {
    @autoreleasepool { // Release payload buffers per revision, not per whole history.
    plain(path, NO);
    NSDictionary *a = [fm attributesOfItemAtPath:path error:nil];
    need([a[NSFileSize] unsignedLongLongValue] <= MAX_REVISION, @"This save snapshot is too large.");
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    need(data.length > 8 && [digest(data) isEqual:ID], @"A save snapshot is damaged. The active save was kept.");
    uint32_t length; memcpy(&length, data.bytes, 4);
    need(length > 0 && length <= 65536 && data.length > length + 4, @"Invalid save snapshot header.");
    NSDictionary *m = dictionary([data subdataWithRange:NSMakeRange(4, length)]);
    need([m[@"format"] isEqual:@1] && [m[@"title"] isEqual:title] && [m[@"player"] isEqual:@"default"] &&
         [m[@"compat"] isKindOfClass:NSString.class] && [m[@"parents"] isKindOfClass:NSArray.class] &&
         [m[@"parents"] count] <= 1024 && [m[@"hash"] isKindOfClass:NSString.class] &&
         [m[@"device"] isKindOfClass:NSString.class] && [m[@"date"] isKindOfClass:NSNumber.class], @"This snapshot belongs to another game/player or uses an unknown format.");
    for (id parent in m[@"parents"]) need(hexID(parent) && ![parent isEqual:ID], @"Invalid save ancestry.");
    NSString *payload = at(vault, [NSUUID.UUID.UUIDString stringByAppendingString:@".archive"]);
    atomicData([data subdataWithRange:NSMakeRange(4 + length, data.length - 4 - length)], payload);
    ss_meta meta;
    int result = ss_read(payload.fileSystemRepresentation, into.fileSystemRepresentation, &meta);
    unlink(payload.fileSystemRepresentation);
    need(result == 0 && [@(meta.title) isEqual:title] && [@(meta.hash) isEqual:m[@"hash"]], @"The complete save inventory did not verify. Nothing was restored.");
    need(meta.files > 0 || [path.stringByDeletingLastPathComponent isEqual:at(vault, @"backups")], @"An empty cloud snapshot cannot replace real progress.");
    return m;
    }
}
static NSString *pack(NSString *source, NSArray *parents, BOOL backup) {
    @autoreleasepool {
    NSString *tmp = at(vault, [NSUUID.UUID.UUIDString stringByAppendingString:@".archive"]);
    @try {
    ss_meta meta;
    need(ss_pack(source.fileSystemRepresentation, title.UTF8String, tmp.fileSystemRepresentation, &meta) == 0, @"Cannot create a complete save snapshot. Local progress was kept.");
    NSDictionary *m = @{@"format":@1, @"title":title, @"player":@"default", @"compat":compat, @"gameVersion":gameVersion,
        @"parents":parents, @"hash":@(meta.hash), @"device":device,
        @"date":@([NSDate.date timeIntervalSince1970]), @"nonce":NSUUID.UUID.UUIDString};
    NSData *header = json(m), *payload = [NSData dataWithContentsOfFile:tmp options:NSDataReadingMappedIfSafe error:nil];
    need(payload != nil && payload.length <= MAX_REVISION - header.length - 4, @"The save is too large or the disk is full. Local progress was kept.");
    need(header.length <= 65536 && parents.count <= 1024, @"Too many conflict branches to combine at once. Every revision was kept.");
    uint32_t length = (uint32_t)header.length;
    NSMutableData *data = [NSMutableData dataWithBytes:&length length:4]; [data appendData:header]; [data appendData:payload];
    need(backup || meta.files > 0, @"Empty progress is never published over a real save.");
    NSString *ID = digest(data);
    NSString *destination = revisionPath(ID);
    if (backup) { mkdirs(at(vault, @"backups")); destination = at(at(vault, @"backups"), [ID stringByAppendingString:suffix]); }
    atomicData(data, destination); unlink(tmp.fileSystemRepresentation);
    readRevision(destination, ID, nil); return ID;
    } @finally { unlink(tmp.fileSystemRepresentation); }
    }
}
static void fault(NSString *point) {
#ifdef NXE_CLOUD_TESTING
    const char *p = getenv("NXE_TEST_CLOUD_CRASH"); if (p && [point isEqual:@(p)]) _exit(86);
    p = getenv("NXE_TEST_CLOUD_FAIL"); if (p && [point isEqual:@(p)]) fail(@"Synthetic disk failure.");
#else
    (void)point;
#endif
}
// A durable journal always rolls forward from a checked, locally retained
// revision. Every displaced tree is retained. A failed recovery blocks play.
static void syncTree(NSString *root);
static void recover(void) {
    NSString *journal = at(vault, @"restore.json"); if (!exists(journal)) return;
    NSDictionary *j = dictionary([NSData dataWithContentsOfFile:journal]);
    NSString *ID = j[@"after"], *before = j[@"before"];
    need(hexID(ID) && hexID(before), @"Restore recovery metadata is damaged. Do not start this game yet.");
    readRevision(at(at(vault, @"backups"), [before stringByAppendingString:suffix]), before, nil);
    NSString *scratch = at(vault, NSUUID.UUID.UUIDString); mkdirs(scratch);
    NSDictionary *m = readRevision(revisionPath(ID), ID, scratch);
    need([m[@"compat"] isEqual:compat], @"Finish recovery with the same game version used for this restore.");
    syncTree(scratch);
    for (NSString *name in @[@"save", @"save_device"]) {
        NSString *prepared = at(scratch, name), *active = [name isEqual:@"save"] ? save : [save stringByAppendingString:@"_device"];
        if (!exists(prepared)) mkdirs(prepared);
        if (exists(active)) {
            plain(active, YES);
            NSString *retained = at(vault, [NSString stringWithFormat:@"retained-%@-%@", name, NSUUID.UUID.UUIDString]);
            need(rename(active.fileSystemRepresentation, retained.fileSystemRepresentation) == 0, @"Cannot preserve the current save during recovery. Play is blocked until recovery completes.");
            syncDir(save.stringByDeletingLastPathComponent); syncDir(vault);
        }
        fault([@"moved-" stringByAppendingString:name]);
        need(rename(prepared.fileSystemRepresentation, active.fileSystemRepresentation) == 0, @"Cannot finish restoring both save folders. Recovery will resume before play.");
        syncDir(save.stringByDeletingLastPathComponent); syncDir(scratch);
        fault([@"installed-" stringByAppendingString:name]);
    }
    need([scan(save) isEqual:m[@"hash"]], @"Restored save did not verify. Recovery remains pending.");
    base(ID, m[@"hash"]); fault(@"state");
    need(unlink(journal.fileSystemRepresentation) == 0, @"Cannot finish the restore journal."); syncDir(vault);
}
static void syncTree(NSString *root) {
    NSDirectoryEnumerator *e = [fm enumeratorAtPath:root];
    for (NSString *relative in e) {
        NSString *p = at(root, relative); struct stat st;
        need(!lstat(p.fileSystemRepresentation, &st) && (S_ISDIR(st.st_mode) || S_ISREG(st.st_mode)), @"Invalid prepared save path.");
        if (S_ISDIR(st.st_mode)) syncDir(p);
    }
    syncDir(root);
}
static void restore(NSString *ID) {
    NSDictionary *m = readRevision(revisionPath(ID), ID, nil);
    need([m[@"compat"] isEqual:compat], @"Use the same game version and content on both devices before restoring.");
    NSString *before = pack(save, @[], YES); // Verified and durable before touching either tree.
    atomicData(json(@{@"before":before, @"after":ID}), at(vault, @"restore.json")); fault(@"journal"); recover();
}
static void initialize(void) {
    if (initialized) return;
    fm = NSFileManager.defaultManager;
    const char *s = getenv("DM_SAVE"), *manifest = getenv("NXE_SAVE_COMPAT");
    need(s && manifest, @"Rebuild this game once to enable save continuity.");
    save = [@(s) stringByStandardizingPath];
    need(save.isAbsolutePath && ![save isEqual:@"/"], @"The local save needs an absolute game-specific path.");
    plain(save.stringByDeletingLastPathComponent, YES);
    vault = [save stringByAppendingString:@".nxe-cloud"];
    mkdirs(vault); mkdirs(at(vault, @"revisions"));
    NSDictionary *m = dictionary([NSData dataWithContentsOfFile:@(manifest)]);
    title = m[@"title"]; compat = m[@"identity"];
    gameVersion = [m[@"version"] isKindOfClass:NSString.class] ? m[@"version"] : @"unknown";
    need([title isKindOfClass:NSString.class] && title.length == 16 && [title rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet]].location == NSNotFound && hexID(compat), @"This game lacks a verified save compatibility identity. Rebuild it before enabling iCloud.");
    device = NSProcessInfo.processInfo.hostName ?: @"This device";
    const char *c = getenv("NXE_CLOUD_FOLDER"); cloud = c && *c ? @(c) : nil; initialized = YES;
}
static void lockGame(void) {
    if (lease >= 0) return;
    int fd = open(at(vault, @"game.lock").fileSystemRepresentation, O_CREAT | O_RDWR | O_NOFOLLOW, 0600);
    need(fd >= 0, @"Cannot lock this game's save history.");
    if (flock(fd, LOCK_EX | LOCK_NB)) { close(fd); fail(@"Another copy of this game is using its saves. Close it first."); }
    lease = fd; // Inherited by the Mac child; the parent never mutates saves while it runs.
}
static void coordinate(NSURL *url, BOOL writing, void (^accessor)(NSURL *)) {
    NSFileCoordinator *c = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ [c cancel]; });
    NSError *error = nil; __block NSException *failure = nil; __block BOOL accessed = NO;
    void (^block)(NSURL *) = ^(NSURL *u) { @autoreleasepool { @try { accessor(u); accessed = YES; } @catch (NSException *e) { failure = e; } } };
    if (writing) [c coordinateWritingItemAtURL:url options:0 error:&error byAccessor:block];
    else [c coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingWithoutChanges error:&error byAccessor:block];
    if (failure) @throw failure;
    need(!error && accessed, @"iCloud is unavailable. Your local save and queued snapshots are safe. Try again later.");
}
static BOOL downloaded(NSURL *url) {
    NSNumber *ubiquitous = nil; NSString *status = nil;
    [url getResourceValue:&ubiquitous forKey:NSURLIsUbiquitousItemKey error:nil];
    if (!ubiquitous.boolValue) return YES;
    [url getResourceValue:&status forKey:NSURLUbiquitousItemDownloadingStatusKey error:nil];
    if ([status isEqual:NSURLUbiquitousItemDownloadingStatusCurrent]) return YES;
    [fm startDownloadingUbiquitousItemAtURL:url error:nil]; return NO;
}
static NSString *cloudDirectory(void) {
    plain(cloud, YES); NSString *root = at(cloud, @"nxnative-saves-v1");
    mkdirs(root); NSString *dir = at(root, title); mkdirs(dir); return dir;
}
static BOOL exchange(void) {
    if (!cloud) return YES;
    __block NSString *dir;
    coordinate([NSURL fileURLWithPath:cloud], YES, ^(NSURL *u) { (void)u; dir = cloudDirectory(); });
    __block BOOL complete = YES;
    __block NSArray<NSURL *> *files;
    coordinate([NSURL fileURLWithPath:dir], NO, ^(NSURL *u) { files = [fm contentsOfDirectoryAtURL:u includingPropertiesForKeys:@[NSURLIsUbiquitousItemKey, NSURLUbiquitousItemDownloadingStatusKey] options:0 error:nil]; need(files != nil, @"Cannot read the selected iCloud folder."); });
    need(files.count <= 10000, @"This history needs a manual archive before more snapshots can be added. All local progress is kept.");
    for (NSURL *url in files) {
        NSString *name = url.lastPathComponent;
        if ([name hasPrefix:@"."] && [name hasSuffix:@".icloud"]) {
            NSString *logical = [name substringWithRange:NSMakeRange(1, name.length - 8)];
            if ([logical hasSuffix:suffix] && hexID(logical.stringByDeletingPathExtension)) {
                complete = NO;
                [fm startDownloadingUbiquitousItemAtURL:[NSURL fileURLWithPath:at(dir, logical)] error:nil];
            }
            continue;
        }
        if (![name hasSuffix:suffix]) continue;
        NSString *ID = [name stringByDeletingPathExtension]; need(hexID(ID), @"An unknown save file needs review. No automatic restore was performed.");
        if (!downloaded(url)) { complete = NO; continue; }
        coordinate(url, NO, ^(NSURL *u) {
            // Validate before making a revision a member of the local graph.
            readRevision(u.path, ID, nil);
            if (!exists(revisionPath(ID))) atomicData([NSData dataWithContentsOfURL:u options:NSDataReadingMappedIfSafe error:nil], revisionPath(ID));
        });
    }
    for (NSString *name in [fm contentsOfDirectoryAtPath:at(vault, @"revisions") error:nil]) {
        if (![name hasSuffix:suffix]) continue;
        NSString *ID = name.stringByDeletingPathExtension; readRevision(revisionPath(ID), ID, nil);
        NSURL *destination = [NSURL fileURLWithPath:at(dir, name)];
        coordinate(destination, YES, ^(NSURL *u) {
            if (exists(u.path)) { if (!downloaded(u)) { complete = NO; return; } readRevision(u.path, ID, nil); }
            else atomicData([NSData dataWithContentsOfFile:revisionPath(ID) options:NSDataReadingMappedIfSafe error:nil], u.path);
        });
    }
    return complete; // In this folder only; never a promise of delivery to another device.
}
static NSDictionary *graph(void) {
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    for (NSString *name in [fm contentsOfDirectoryAtPath:at(vault, @"revisions") error:nil]) {
        if ([name hasSuffix:suffix]) { NSString *ID = name.stringByDeletingPathExtension; all[ID] = readRevision(revisionPath(ID), ID, nil); }
    }
    return all;
}
static NSArray *heads(NSDictionary *all) {
    NSMutableSet *h = [NSMutableSet setWithArray:all.allKeys];
    for (NSDictionary *m in all.allValues) for (NSString *p in m[@"parents"]) { need(all[p] != nil, @"Waiting for an earlier iCloud revision to download. Local progress was kept."); [h removeObject:p]; }
    return [[h allObjects] sortedArrayUsingSelector:@selector(compare:)];
}
static BOOL descendant(NSString *tip, NSString *ancestor, NSDictionary *all) {
    NSMutableArray *todo = [NSMutableArray arrayWithObject:tip]; NSMutableSet *seen = [NSMutableSet set];
    while (todo.count) { NSString *s = todo.lastObject; [todo removeLastObject]; if ([s isEqual:ancestor]) return YES; if ([seen containsObject:s]) continue; [seen addObject:s]; [todo addObjectsFromArray:all[s][@"parents"] ?: @[]]; }
    return NO;
}
static NSString *captureLocal(void) {
    NSDictionary *s = state(); NSString *hash = scan(save);
    if ([s[@"hash"] isEqual:hash] && hexID(s[@"base"]) && exists(revisionPath(s[@"base"]))) return s[@"base"];
    if (!hash.length) return nil; // Never publish an empty save over real progress.
    NSString *ID = pack(save, hexID(s[@"base"]) ? @[s[@"base"]] : @[], NO);
    base(ID, hash); return ID;
}
static NSDictionary *check(BOOL mayRestore) {
    recover(); localSafe = YES;
    if (!cloud) return @{@"status":@"local", @"message":@"Saved on this device. Choose the same iCloud Drive folder on both devices to continue elsewhere.", @"choices":@[]};
    NSString *local = captureLocal();
    BOOL complete = exchange(); NSDictionary *all = graph(); NSArray *h = heads(all);
    if (complete && mayRestore && h.count == 1 && (![local length] || descendant(h[0], local, all))) {
        NSDictionary *m = all[h[0]];
        if (![local isEqual:h[0]]) { restore(h[0]); local = h[0]; }
        need([m[@"compat"] isEqual:compat], @"Use the same game version and content on both devices. Both saves were kept.");
    }
    NSMutableArray *choices = [NSMutableArray array];
    for (NSString *ID in h) { NSDictionary *m = all[ID]; [choices addObject:@{@"id":ID, @"device":m[@"device"], @"date":m[@"date"], @"compatible":@([m[@"compat"] isEqual:compat]), @"local":@([local isEqual:ID])}]; }
    NSMutableArray *history = [NSMutableArray array];
    for (NSString *ID in [all.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *m = all[ID];
        [history addObject:@{@"id":ID, @"device":m[@"device"], @"date":m[@"date"], @"compatible":@([m[@"compat"] isEqual:compat]), @"local":@([local isEqual:ID])}];
    }
    [history sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [b[@"date"] compare:a[@"date"]]; }];
    BOOL conflict = h.count > 1;
    NSString *status = conflict ? @"conflict" : !complete ? @"waiting" : !h.count ? @"empty" : @"available";
    NSString *message = !h.count ? @"No save yet. Save in the game to queue your first snapshot." : conflict ? @"Different progress was found. Both versions are kept. Choose which one to continue; the other remains in history." : !complete ? @"Saved locally. Waiting for iCloud to download every revision. You can keep playing locally." : @"Snapshot available in the selected folder. Wait for iCloud to deliver it before playing on the other device.";
    return @{@"status":status, @"message":message, @"choices":choices, @"history":history};
}
static NSDictionary *command(NSString *cmd, NSString *arg) {
    initialize();
    if ([cmd isEqual:@"host"]) { playing = YES; return @{}; }
    lockGame(); recover(); localSafe = YES;
    if ([cmd isEqual:@"local-play"]) { playing = YES; return @{@"status":@"local", @"message":@"Playing locally; cloud snapshots remain queued.", @"choices":@[]}; }
    if ([cmd isEqual:@"folder"]) { need(!playing, @"Close and reopen the game before changing save settings."); cloud = arg.length ? arg : nil; if (cloud) setenv("NXE_CLOUD_FOLDER", cloud.fileSystemRepresentation, 1); else unsetenv("NXE_CLOUD_FOLDER"); }
    if ([cmd isEqual:@"resolve"]) {
        need(!playing && cloud != nil, @"Choose a save before starting the game.");
        captureLocal(); need(exchange(), @"Wait for every iCloud revision to download before choosing a save.");
        NSDictionary *all = graph(); NSArray *h = heads(all);
        need(all[arg] != nil && [all[arg][@"compat"] isEqual:compat], @"This revision changed or has different game content. Check again.");
        NSString *tmp = at(vault, NSUUID.UUID.UUIDString); mkdirs(tmp);
        readRevision(revisionPath(arg), arg, tmp);
        NSString *resolution = pack(at(tmp, @"save"), h, NO);
        restore(resolution); exchange();
    }
    NSDictionary *result = check(!playing);
    if ([cmd isEqual:@"play"] && ![@[@"conflict", @"waiting", @"error"] containsObject:result[@"status"]]) playing = YES;
    return result;
}
static void setupQueue(void) { static dispatch_once_t once; dispatch_once(&once, ^{ queue = dispatch_queue_create("org.nxnative.save-continuity", DISPATCH_QUEUE_SERIAL); workers = dispatch_group_create(); }); }
char *nxe_cloud_command(const char *cmd, const char *arg) {
    setupQueue(); __block NSDictionary *result;
    dispatch_sync(queue, ^{ @autoreleasepool { @try { result = command(@(cmd), arg ? @(arg) : @""); }
        @catch (NSException *e) { result = @{@"status":@"error", @"message":e.reason ?: @"Save check failed.", @"choices":@[], @"blocksPlay":@(!localSafe || (vault && exists(at(vault, @"restore.json"))))}; } } });
    return strdup([[NSString alloc] initWithData:json(result) encoding:NSUTF8StringEncoding].UTF8String);
}
__attribute__((weak)) int dm_fs_clone_save_pair(const char *source, const char *into) { (void)source; (void)into; return -1; }
#ifdef NXE_CLOUD_TESTING
__attribute__((weak)) void nxe_cloud_test_claimed(void) {}
#endif
static _Atomic unsigned long long requested;
void nxe_cloud_committed(void) {
    // Off means no queue, snapshots or provider I/O on game commits.
    const char *selected = getenv("NXE_CLOUD_FOLDER"); if (!selected || !*selected) return;
    // A bounded/coalesced worker; no network I/O under game filesystem locks.
    setupQueue(); static _Atomic int pending;
    __c11_atomic_fetch_add(&requested, 1, __ATOMIC_SEQ_CST);
    // Enter before claiming pending: a concurrent flush must observe the claim
    // even if this thread is preempted before it can schedule the worker.
    dispatch_group_enter(workers);
    if (__c11_atomic_exchange(&pending, 1, __ATOMIC_SEQ_CST)) { dispatch_group_leave(workers); return; }
    #ifdef NXE_CLOUD_TESTING
    nxe_cloud_test_claimed();
    #endif
    dispatch_async(queue, ^{ @autoreleasepool {
        unsigned long long captured = __c11_atomic_load(&requested, __ATOMIC_SEQ_CST);
        @try {
            initialize(); playing = YES;
            if (cloud) {
                NSString *tmp = at(vault, NSUUID.UUID.UUIDString); mkdirs(tmp);
                need(dm_fs_clone_save_pair(save.fileSystemRepresentation, tmp.fileSystemRepresentation) == 0, @"Cannot snapshot committed saves.");
                NSString *hash = scan(at(tmp, @"save")); NSDictionary *s = state();
                if (hash.length && ![s[@"hash"] isEqual:hash]) { NSString *ID = pack(at(tmp, @"save"), hexID(s[@"base"]) ? @[s[@"base"]] : @[], NO); base(ID, hash); }
                exchange();
                [fm removeItemAtPath:tmp error:nil];
            }
        } @catch (NSException *e) { fprintf(stderr, "[dm] save continuity: %s\n", e.reason.UTF8String); }
        __c11_atomic_store(&pending, 0, __ATOMIC_SEQ_CST);
        if (captured != __c11_atomic_load(&requested, __ATOMIC_SEQ_CST)) nxe_cloud_committed();
        dispatch_group_leave(workers);
    } });
}

void nxe_cloud_flush(void (*done)(void *), void *context) {
    setupQueue(); nxe_cloud_committed();
    dispatch_group_notify(workers, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ if (done) done(context); });
}
