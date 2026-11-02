// Isolated command-line fixture; tests supply every path. Never opens a device.
#import <Foundation/Foundation.h>
#include "cloud_saves.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
int main(int argc, char **argv) { @autoreleasepool {
    if (argc < 2) return 2;
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
