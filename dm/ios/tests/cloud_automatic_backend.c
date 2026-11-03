// Launcher-only fixture. It cannot access files, iCloud, accounts or devices.
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static char *reply;
static int calls;
static char last_command[32];
void nxe_test_reset(const char *json) {
    pthread_mutex_lock(&lock);
    free(reply); reply = strdup(json); calls = 0; last_command[0] = 0;
    pthread_mutex_unlock(&lock);
}
void nxe_test_reply(const char *json) {
    pthread_mutex_lock(&lock);
    free(reply); reply = strdup(json);
    pthread_mutex_unlock(&lock);
}
int nxe_test_calls(void) {
    pthread_mutex_lock(&lock); int n = calls; pthread_mutex_unlock(&lock); return n;
}
char *nxe_test_last(void) {
    pthread_mutex_lock(&lock); char *s = strdup(last_command); pthread_mutex_unlock(&lock); return s;
}
char *nxe_cloud_command(const char *command, const char *argument) {
    (void)argument;
    pthread_mutex_lock(&lock);
    calls++; strncpy(last_command, command, sizeof last_command - 1);
    char *result = strdup(reply);
    pthread_mutex_unlock(&lock);
    return result;
}
