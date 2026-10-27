// Four named touch-control presets per game. Foundation-only so native tests use the runtime storage.
#import <Foundation/Foundation.h>
#import "DmPadGeometry.h"

static inline NSArray<NSString *> *dm_pad_control_ids(void) {
    return @[@"A",@"B",@"X",@"Y",@"L3",@"R3",@"L",@"R",@"ZL",@"ZR",@"Plus",@"Minus",@"Stick",@"Dpad"];
}
static inline NSDictionary *dm_pad_clean_controls(id source) {
    if (![source isKindOfClass:NSDictionary.class]) return @{};
    NSMutableDictionary *out=[NSMutableDictionary dictionary];
    for (NSString *key in dm_pad_control_ids()) if (dm_pad_entry_valid(source[key])) out[key]=[source[key] copy];
    return [out copy];
}

@interface DmPadProfiles : NSObject
@property(nonatomic,readonly) NSInteger selected;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults game:(NSString *)game;
- (NSString *)name:(NSInteger)slot;
- (NSDictionary *)controls:(NSString *)layout slot:(NSInteger)slot;
- (void)select:(NSInteger)slot;
- (BOOL)rename:(NSInteger)slot name:(NSString *)name;
- (void)save:(NSDictionary *)controls layout:(NSString *)layout slot:(NSInteger)slot;
- (void)copySlot:(NSInteger)source to:(NSInteger)target draft:(NSDictionary *)controls layout:(NSString *)layout;
@end

@implementation DmPadProfiles {
    NSUserDefaults *_defaults;
    NSString *_key;
    NSMutableArray<NSMutableDictionary *> *_slots;
    NSInteger _selected;
}
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults game:(NSString *)game {
    if ((self=[super init])) {
        _defaults=defaults;_key=[@"DmPadProfiles.v2." stringByAppendingString:game];
        _slots=[NSMutableArray array];
        id raw=[defaults objectForKey:_key];
        NSDictionary *saved=[raw isKindOfClass:NSDictionary.class] && [raw[@"schema"] isEqual:@2] ? raw : nil;
        NSArray *slots=[saved[@"slots"] isKindOfClass:NSArray.class] ? saved[@"slots"] : @[];
        for (NSInteger i=0;i<4;i++) {
            NSDictionary *slot=i<(NSInteger)slots.count && [slots[i] isKindOfClass:NSDictionary.class] ? slots[i] : @{};
            NSString *name=[slot[@"name"] isKindOfClass:NSString.class] ? slot[@"name"] : @"";
            name=[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (!name.length || name.length>32) name=[NSString stringWithFormat:@"Profile %ld",(long)i+1];
            NSDictionary *layouts=[slot[@"layouts"] isKindOfClass:NSDictionary.class] ? slot[@"layouts"] : @{};
            [_slots addObject:[@{@"name":name,@"layouts":[@{@"2D":dm_pad_clean_controls(layouts[@"2D"]),@"3D":dm_pad_clean_controls(layouts[@"3D"])} mutableCopy]} mutableCopy]];
        }
        NSNumber *selected=[saved[@"selected"] isKindOfClass:NSNumber.class] ? saved[@"selected"] : @0;
        _selected=selected.integerValue>=0 && selected.integerValue<4 ? selected.integerValue : 0;
        if (!saved) {
            // Copy both legacy layouts once; never remove their original preference keys.
            _slots[0][@"layouts"]=[@{@"2D":dm_pad_clean_controls([defaults objectForKey:@"DmPadControls.v1.2D"]),
                                      @"3D":dm_pad_clean_controls([defaults objectForKey:@"DmPadControls.v1.3D"])} mutableCopy];
            [self persist];
        }
    }
    return self;
}
- (BOOL)validSlot:(NSInteger)slot { return slot>=0 && slot<4; }
- (BOOL)validLayout:(NSString *)layout { return [@[@"2D",@"3D"] containsObject:layout]; }
- (void)persist { [_defaults setObject:@{@"schema":@2,@"selected":@(_selected),@"slots":_slots} forKey:_key]; }
- (NSInteger)selected { return _selected; }
- (NSString *)name:(NSInteger)slot { return [self validSlot:slot] ? _slots[slot][@"name"] : @""; }
- (NSDictionary *)controls:(NSString *)layout slot:(NSInteger)slot {
    return [self validSlot:slot] && [self validLayout:layout] ? dm_pad_clean_controls(_slots[slot][@"layouts"][layout]) : @{};
}
- (void)select:(NSInteger)slot { if ([self validSlot:slot]) { _selected=slot;[self persist]; } }
- (BOOL)rename:(NSInteger)slot name:(NSString *)name {
    if (![self validSlot:slot]) return NO;
    name=[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!name.length || name.length>32 || [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound) return NO;
    _slots[slot][@"name"]=name;[self persist];return YES;
}
- (void)save:(NSDictionary *)controls layout:(NSString *)layout slot:(NSInteger)slot {
    if (![self validSlot:slot] || ![self validLayout:layout]) return;
    _slots[slot][@"layouts"][layout]=dm_pad_clean_controls(controls);[self persist];
}
- (void)copySlot:(NSInteger)source to:(NSInteger)target draft:(NSDictionary *)controls layout:(NSString *)layout {
    if (![self validSlot:source] || ![self validSlot:target] || ![self validLayout:layout] || source==target) return;
    // Copy both layouts, replacing only the current layout with the visible draft. Keep the target's name.
    NSMutableDictionary *layouts=[@{@"2D":[self controls:@"2D" slot:source],@"3D":[self controls:@"3D" slot:source]} mutableCopy];
    layouts[layout]=dm_pad_clean_controls(controls);_slots[target][@"layouts"]=layouts;_selected=target;[self persist];
}
@end
