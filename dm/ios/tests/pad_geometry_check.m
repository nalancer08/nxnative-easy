#import "../Sources/DmPadGeometry.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    NSDictionary *valid = @{@"x":@0.9,@"y":@0.2,@"scale":@2,@"alpha":@0};
    assert(dm_pad_entry_valid(valid));
    for (NSString *key in valid) for (id bad in @[@"0.5", @YES, @(NAN), @(INFINITY), @(-1), @3, NSNull.null]) {
        NSMutableDictionary *v=[valid mutableCopy]; v[key]=bad; assert(!dm_pad_entry_valid(v));
    }
    assert(!dm_pad_entry_valid(@[]) && !dm_pad_entry_valid(@{}));
    CGRect landscape=CGRectMake(40,20,800,380), portrait=CGRectMake(0,40,380,800);
    CGPoint p=dm_pad_position(valid,CGPointZero,landscape,30);
    assert(p.x==760 && p.y==96);
    CGPoint q=dm_pad_position(valid,CGPointZero,portrait,30);
    assert(q.x==342 && q.y==200);
    q=dm_pad_clamp(CGPointMake(-900,9000),landscape,60); assert(q.x==100 && q.y==340);
    q=dm_pad_position(nil,CGPointMake(12,34),landscape,30); assert(q.x==12 && q.y==34);
    assert(dm_pad_distance(p,p,27*2*1.25)==0);
    assert(dm_pad_distance(CGPointMake(p.x+60,p.y),p,27*2*1.25)<1);
    assert(dm_pad_distance(CGPointMake(p.x+60,p.y),p,27*0.5*1.25)>1);
    NSUserDefaults *d=[[NSUserDefaults alloc] initWithSuiteName:@"nxnative.pad.geometry.tests"];
    [d removePersistentDomainForName:@"nxnative.pad.geometry.tests"];
    [d setObject:@{@"A":valid} forKey:@"DmPadControls.v1.2D"];
    NSMutableDictionary *draft=[[d dictionaryForKey:@"DmPadControls.v1.2D"] mutableCopy];
    [draft removeAllObjects]; // Cancel reloads saved data, without writing the draft.
    assert(dm_pad_entry_valid([d dictionaryForKey:@"DmPadControls.v1.2D"][@"A"]));
    assert([d dictionaryForKey:@"DmPadControls.v1.3D"]==nil);
    [d setObject:draft forKey:@"DmPadControls.v1.2D"]; // Save confirms reset.
    assert([d dictionaryForKey:@"DmPadControls.v1.2D"].count==0);
    [d removePersistentDomainForName:@"nxnative.pad.geometry.tests"];
    puts("pad geometry: PASS (invalid preferences, limits, rotation, moved hit regions, persistence and cancelled draft)");
} }
