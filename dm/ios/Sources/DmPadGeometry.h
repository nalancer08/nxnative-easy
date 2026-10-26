// Shared by the runtime and native regression tests; no UIKit dependency.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
static inline BOOL dm_pad_entry_valid(id value) {
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    for (NSString *key in @[@"x", @"y", @"scale", @"alpha"]) {
        id number = value[key]; BOOL scale = [key isEqual:@"scale"];
        if (![number isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID()) return NO;
        double n = [number doubleValue];
        if (!isfinite(n) || n < (scale ? 0.5 : 0) || n > (scale ? 2 : 1)) return NO;
    }
    return YES;
}
static inline CGPoint dm_pad_clamp(CGPoint p, CGRect r, CGFloat margin) {
    CGFloat mx = MIN(margin, r.size.width / 2), my = MIN(margin, r.size.height / 2);
    return CGPointMake(fmin(fmax(p.x, CGRectGetMinX(r)+mx), CGRectGetMaxX(r)-mx),
                       fmin(fmax(p.y, CGRectGetMinY(r)+my), CGRectGetMaxY(r)-my));
}
static inline CGPoint dm_pad_position(NSDictionary *v, CGPoint original, CGRect r, CGFloat margin) {
    if (!v) return original;
    CGPoint p = CGPointMake(r.origin.x + [v[@"x"] doubleValue]*r.size.width,
                           r.origin.y + [v[@"y"] doubleValue]*r.size.height);
    return dm_pad_clamp(p, r, margin);
}
static inline CGFloat dm_pad_distance(CGPoint p, CGPoint c, CGFloat radius) {
    return radius > 0 ? hypot(p.x-c.x,p.y-c.y)/radius : INFINITY;
}
