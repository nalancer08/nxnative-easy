// Isolated command-line fixture; tests supply every path. Never opens a device.
#import <Foundation/Foundation.h>
#include "cloud_saves.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/clonefile.h>
#include <sys/stat.h>
#include <limits.h>
int dm_fs_clone_save_pair(const char *source, const char *into) {
    for (int i = 0; i < 2; i++) {
        char from[PATH_MAX], to[PATH_MAX]; struct stat st;
        snprintf(from, sizeof from, i ? "%s_device" : "%s", source);
        snprintf(to, sizeof to, "%s/%s", into, i ? "save_device" : "save");
        if (lstat(from, &st)) { if (errno == ENOENT) continue; return -1; }
        if (!S_ISDIR(st.st_mode) || clonefile(from, to, 0)) return -1;
    }
    return 0;
}
static void flushed(void *context) { dispatch_semaphore_signal((__bridge dispatch_semaphore_t)context); }
int main(int argc, char **argv) { @autoreleasepool {
    if (argc < 2) return 2;
    if (!strcmp(argv[1], "flush")) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        nxe_cloud_flush(flushed, (__bridge void *)semaphore);
        if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC))) return 3;
        puts("{\"status\":\"flushed\"}"); return 0;
    }
    if (!strcmp(argv[1], "serve")) {
        char line[4096];
        while (fgets(line, sizeof line, stdin)) {
            line[strcspn(line, "\n")] = 0;
            char *argument = strchr(line, ' ');
            if (argument) *argument++ = 0;
            char *result = nxe_cloud_command(line, argument ?: "");
            puts(result); fflush(stdout); free(result);
        }
        return 0;
    }
    char *reply = nxe_cloud_command(argv[1], argc > 2 ? argv[2] : "");
    puts(reply); fflush(stdout); free(reply);
    if (getenv("NXE_TEST_HOLD_LEASE")) sleep(3);
    return 0;
} }
