// Packed save integrity/guest-name preservation; adapted from seedds/nxnative (MIT).
#pragma once
#include <stdint.h>
#define SS_HASH 32
typedef struct { char hash[SS_HASH + 1]; int64_t saved; char title[24], device[64]; int files; } ss_meta;
int ss_scan(const char *save, ss_meta *m);
int ss_pack(const char *save, const char *title, const char *out, ss_meta *m);
int ss_read(const char *bundle, const char *into, ss_meta *m);
