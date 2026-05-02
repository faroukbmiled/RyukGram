// Hide the friends-map note tile in the DM inbox notes tray. The tile is its
// own IGListKit section; returning zero items collapses it without any cell
// or sizing fights.

#import "../../Utils.h"

%hook _TtC24IGDirectNotesTrayUISwift43IGDirectNotesTrayFriendMapSectionController

- (NSInteger)numberOfItems {
    if ([SCIUtils getBoolPref:@"hide_friends_map"]) return 0;
    return %orig;
}

- (CGSize)sizeForItemAtIndex:(NSInteger)index {
    if ([SCIUtils getBoolPref:@"hide_friends_map"]) return CGSizeZero;
    return %orig;
}

%end
