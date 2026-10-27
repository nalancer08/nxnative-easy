#import "../Sources/DmPadProfiles.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    NSString *suite=[@"nxnative.pad.profiles.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
    NSDictionary *button=@{@"x":@0.9,@"y":@0.2,@"scale":@1.5,@"alpha":@0.6};
    NSDictionary *legacy=@{@"A":button};
    [defaults setObject:legacy forKey:@"DmPadControls.v1.2D"];
    [defaults setObject:@{@"Stick":button} forKey:@"DmPadControls.v1.3D"];
    DmPadProfiles *profiles=[[DmPadProfiles alloc] initWithDefaults:defaults game:@"game-one"];
    assert(profiles.selected==0 && [[profiles controls:@"2D" slot:0] isEqual:legacy]);
    assert([[profiles controls:@"3D" slot:0][@"Stick"] isEqual:button]);
    assert([[defaults objectForKey:@"DmPadControls.v1.2D"] isEqual:legacy]);
    assert([profiles controls:@"2D" slot:3].count==0);
    assert([profiles rename:0 name:@" iPhone "] && [[profiles name:0] isEqual:@"iPhone"]);
    assert(![profiles rename:0 name:@"   "] && ![profiles rename:0 name:@"bad\nname"]);
    assert(![profiles rename:0 name:[@"x" stringByPaddingToLength:33 withString:@"x" startingAtIndex:0]]);
    assert(![profiles rename:4 name:@"out of bounds"]);
    NSMutableDictionary *draft=[[profiles controls:@"2D" slot:0] mutableCopy];
    [draft removeAllObjects]; // Cancel is a reload: no draft writes until Save or Save as.
    assert([[profiles controls:@"2D" slot:0] isEqual:legacy]);
    [profiles rename:1 name:@"iPad"];
    [profiles copySlot:0 to:1 draft:@{@"B":button} layout:@"2D"];
    assert(profiles.selected==1 && [[profiles name:1] isEqual:@"iPad"]);
    assert([[profiles controls:@"2D" slot:0] isEqual:legacy]);
    assert([[profiles controls:@"2D" slot:1][@"B"] isEqual:button]);
    assert([[profiles controls:@"3D" slot:1][@"Stick"] isEqual:button]);
    [profiles save:@{} layout:@"3D" slot:1];
    assert([profiles controls:@"3D" slot:1].count==0 && [profiles controls:@"3D" slot:0].count==1);
    [profiles select:3];[profiles save:@{@"Dpad":button} layout:@"3D" slot:3];
    DmPadProfiles *reopened=[[DmPadProfiles alloc] initWithDefaults:defaults game:@"game-one"];
    assert(reopened.selected==3 && [[reopened name:1] isEqual:@"iPad"]);
    assert([[reopened controls:@"3D" slot:3][@"Dpad"] isEqual:button]);
    DmPadProfiles *other=[[DmPadProfiles alloc] initWithDefaults:defaults game:@"game-two"];
    assert(other.selected==0 && [[other name:1] isEqual:@"Profile 2"] && [other controls:@"3D" slot:3].count==0);
    // Malformed stored values must not become hit regions or crash the runtime.
    [defaults setObject:@{@"schema":@2,@"selected":@99,@"slots":@[@{@"name":@42,@"layouts":@{@"2D":@{@"A":@{@"x":@YES},@"B":button,@"unknown":button}}},@"invalid slot"]} forKey:@"DmPadProfiles.v2.bad"];
    DmPadProfiles *bad=[[DmPadProfiles alloc] initWithDefaults:defaults game:@"bad"];
    assert(bad.selected==0 && [[bad name:0] isEqual:@"Profile 1"]);
    assert([bad controls:@"2D" slot:0].count==1 && [bad controls:@"2D" slot:0][@"B"]);
    [bad select:-1];[bad save:legacy layout:@"Tap" slot:0];assert(bad.selected==0);
    [defaults removePersistentDomainForName:suite];
    puts("pad profiles: PASS (four slots, names, migration, copy, cancel, layouts, game isolation, relaunch and corrupt preferences)");
} }
