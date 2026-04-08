#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>
#import <substrate.h>

// ============ KEEP DELETED MESSAGES ============
// Blocks remote unsends while allowing local deletes-for-you.
//
// IGDirectMessageUpdate._removeMessages_reason: 0 = unsend, 2 = delete-for-you.
// Delete-for-you fires reason=2 first, then a reason=0 follow-up. Remote
// unsends only fire reason=0. We remember the message keys from reason=2
// updates; a later reason=0 with matching keys is passed through (it's the
// follow-up), anything else is treated as a remote unsend and blocked.
// Tracked keys expire after 10s so a partial delete-for-you can't permanently
// swallow future remote unsends.

static BOOL sciKeepDeletedEnabled() {
    return [SCIUtils getBoolPref:@"keep_deleted_message"];
}

static BOOL sciIndicateUnsentEnabled() {
    return [SCIUtils getBoolPref:@"indicate_unsent_messages"];
}

static void sciUpdateCellIndicator(id cell);
static BOOL sciLocalDeleteInProgress = NO;
static NSMutableArray *sciPendingUpdates = nil;
// Server message ID -> timestamp the reason=2 (delete-for-you) was observed.
static NSMutableDictionary<NSString *, NSDate *> *sciDeleteForYouKeys = nil;
static NSMutableSet *sciPreservedIds = nil;
// Server message ID -> content class name for messages we recognize as
// reaction/action-log bookkeeping (e.g. "X liked a message" thread entries).
// Populated by hooking the data model class init. Used to skip preserving
// these IDs when their remove arrives.
static NSMutableDictionary<NSString *, NSString *> *sciMessageContentClasses = nil;
#define SCI_CONTENT_CLASSES_MAX 4000
#define SCI_PENDING_MAX 50

#define SCI_PRESERVED_IDS_KEY @"SCIPreservedMsgIds"
#define SCI_PRESERVED_MAX 200
#define SCI_PRESERVED_TAG 1399

NSMutableSet *sciGetPreservedIds() {
    if (!sciPreservedIds) {
        NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:SCI_PRESERVED_IDS_KEY];
        sciPreservedIds = saved ? [NSMutableSet setWithArray:saved] : [NSMutableSet set];
    }
    return sciPreservedIds;
}

static void sciSavePreservedIds() {
    NSMutableSet *ids = sciGetPreservedIds();
    while (ids.count > SCI_PRESERVED_MAX)
        [ids removeObject:[ids anyObject]];
    [[NSUserDefaults standardUserDefaults] setObject:[ids allObjects] forKey:SCI_PRESERVED_IDS_KEY];
}

void sciClearPreservedIds() {
    [sciGetPreservedIds() removeAllObjects];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SCI_PRESERVED_IDS_KEY];
}

static NSMutableDictionary<NSString *, NSString *> *sciGetContentClasses() {
    if (!sciMessageContentClasses) sciMessageContentClasses = [NSMutableDictionary dictionary];
    return sciMessageContentClasses;
}

static void sciTrackInsertedMessage(NSString *sid, NSString *className) {
    if (!sid.length || !className.length) return;
    NSMutableDictionary *map = sciGetContentClasses();
    map[sid] = className;
    if (map.count > SCI_CONTENT_CLASSES_MAX) {
        // Drop ~10% oldest by simply removing arbitrary keys
        NSArray *keys = [map allKeys];
        for (NSUInteger i = 0; i < keys.count / 10; i++) [map removeObjectForKey:keys[i]];
    }
}

// Returns YES if the message at this server ID is known to be reaction-related
// (action log entry, reaction record, etc.) — i.e. should never be preserved.
static BOOL sciIsReactionRelatedMessage(NSString *sid) {
    if (!sid.length) return NO;
    NSString *className = sciGetContentClasses()[sid];
    if (!className.length) return NO;
    return [className containsString:@"Reaction"] ||
           [className containsString:@"ActionLog"] ||
           [className containsString:@"reaction"] ||
           [className containsString:@"actionLog"];
}

// ============ ALLOC TRACKING ============

static id (*orig_msgUpdate_alloc)(id self, SEL _cmd);
static id new_msgUpdate_alloc(id self, SEL _cmd) {
    id instance = orig_msgUpdate_alloc(self, _cmd);
    if (sciKeepDeletedEnabled() && instance) {
        if (!sciPendingUpdates) sciPendingUpdates = [NSMutableArray array];
        @synchronized(sciPendingUpdates) {
            [sciPendingUpdates addObject:instance];
            while (sciPendingUpdates.count > SCI_PENDING_MAX)
                [sciPendingUpdates removeObjectAtIndex:0];
        }
    }
    return instance;
}


// ============ REMOTE UNSEND DETECTION ============

static NSString *sciExtractServerId(id key) {
    @try {
        Ivar sidIvar = class_getInstanceVariable([key class], "_messageServerId");
        if (sidIvar) {
            NSString *sid = object_getIvar(key, sidIvar);
            if ([sid isKindOfClass:[NSString class]] && sid.length > 0) return sid;
        }
    } @catch(id e) {}
    return nil;
}

static void sciPruneStaleDeleteForYouKeys() {
    if (!sciDeleteForYouKeys) return;
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-10.0];
    NSArray *allKeys = [sciDeleteForYouKeys allKeys];
    for (NSString *k in allKeys) {
        if ([sciDeleteForYouKeys[k] compare:cutoff] == NSOrderedAscending)
            [sciDeleteForYouKeys removeObjectForKey:k];
    }
}

// Walks every pending IGDirectMessageUpdate, preserves the IDs of any reason=0
// remove that isn't a delete-for-you follow-up, and returns the set of preserved
// IDs. The caller decides whether to actually block + show a toast based on
// whether those IDs match real (rendered) messages.
static NSSet<NSString *> *sciConsumePendingPreserves() {
    NSMutableSet<NSString *> *preserved = [NSMutableSet set];
    if (!sciPendingUpdates) return preserved;
    if (!sciDeleteForYouKeys) sciDeleteForYouKeys = [NSMutableDictionary dictionary];

    sciPruneStaleDeleteForYouKeys();

    @synchronized(sciPendingUpdates) {
        for (id update in [sciPendingUpdates copy]) {
            @try {
                Ivar removeIvar = class_getInstanceVariable([update class], "_removeMessages_messageKeys");
                if (!removeIvar) continue;
                NSArray *keys = object_getIvar(update, removeIvar);
                if (!keys || keys.count == 0) continue;

                long long reason = -1;
                Ivar reasonIvar = class_getInstanceVariable([update class], "_removeMessages_reason");
                if (reasonIvar) {
                    ptrdiff_t off = ivar_getOffset(reasonIvar);
                    reason = *(long long *)((char *)(__bridge void *)update + off);
                }

                // Delete-for-you initiator — remember keys for the follow-up.
                if (reason == 2) {
                    NSDate *now = [NSDate date];
                    for (id key in keys) {
                        NSString *sid = sciExtractServerId(key);
                        if (sid) sciDeleteForYouKeys[sid] = now;
                    }
                    continue;
                }

                if (reason != 0 || sciLocalDeleteInProgress) continue;

                // If every key matches a recent delete-for-you, drop the
                // tracking entries and let it through (it's the follow-up).
                BOOL allMatched = YES;
                for (id key in keys) {
                    NSString *sid = sciExtractServerId(key);
                    if (!sid || !sciDeleteForYouKeys[sid]) { allMatched = NO; break; }
                }
                if (allMatched) {
                    for (id key in keys) {
                        NSString *sid = sciExtractServerId(key);
                        if (sid) [sciDeleteForYouKeys removeObjectForKey:sid];
                    }
                    continue;
                }

                // Real remove — preserve only keys whose content class isn't a
                // known reaction / action-log entry. Reaction events also fire
                // reason=0 removes for the action-log record they create.
                for (id key in keys) {
                    NSString *sid = sciExtractServerId(key);
                    if (!sid) continue;
                    if (sciIsReactionRelatedMessage(sid)) continue;
                    [sciGetPreservedIds() addObject:sid];
                    [preserved addObject:sid];
                }
            } @catch(id e) {}
        }
        [sciPendingUpdates removeAllObjects];
    }
    if (preserved.count > 0) sciSavePreservedIds();
    return preserved;
}

// ============ CACHE UPDATE HOOK ============

static void (*orig_applyUpdates)(id self, SEL _cmd, id updates, id completion, id userAccess);
static void new_applyUpdates(id self, SEL _cmd, id updates, id completion, id userAccess) {
    if (!sciKeepDeletedEnabled()) {
        orig_applyUpdates(self, _cmd, updates, completion, userAccess);
        return;
    }

    NSSet<NSString *> *preserved = sciConsumePendingPreserves();

    if (preserved.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Refresh visible cells so newly preserved messages show the
            // "Unsent" indicator immediately without waiting for a scroll.
            Class cellClass = NSClassFromString(@"IGDirectMessageCell");
            if (cellClass) {
                UIWindow *window = [UIApplication sharedApplication].keyWindow;
                NSMutableArray *stack = [NSMutableArray arrayWithObject:window];
                while (stack.count > 0) {
                    UIView *v = stack.lastObject;
                    [stack removeLastObject];
                    if ([v isKindOfClass:cellClass]) {
                        sciUpdateCellIndicator(v);
                        continue;
                    }
                    for (UIView *sub in v.subviews)
                        [stack addObject:sub];
                }
            }

            // Top-of-screen toast notifying the user that an unsend was caught.
            if ([SCIUtils getBoolPref:@"unsent_message_toast"]) {
                UIView *hostView = [UIApplication sharedApplication].keyWindow;
                if (hostView) {
                    UIView *pill = [[UIView alloc] init];
                    pill.backgroundColor = [UIColor colorWithRed:0.85 green:0.15 blue:0.15 alpha:0.95];
                    pill.layer.cornerRadius = 18;
                    pill.layer.shadowColor = [UIColor blackColor].CGColor;
                    pill.layer.shadowOpacity = 0.4;
                    pill.layer.shadowOffset = CGSizeMake(0, 2);
                    pill.layer.shadowRadius = 8;
                    pill.translatesAutoresizingMaskIntoConstraints = NO;
                    pill.alpha = 0;

                    UILabel *label = [[UILabel alloc] init];
                    label.text = @"A message was unsent";
                    label.textColor = [UIColor whiteColor];
                    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
                    label.textAlignment = NSTextAlignmentCenter;
                    label.translatesAutoresizingMaskIntoConstraints = NO;
                    [pill addSubview:label];

                    [hostView addSubview:pill];

                    [NSLayoutConstraint activateConstraints:@[
                        [pill.topAnchor constraintEqualToAnchor:hostView.safeAreaLayoutGuide.topAnchor constant:8],
                        [pill.centerXAnchor constraintEqualToAnchor:hostView.centerXAnchor],
                        [pill.heightAnchor constraintEqualToConstant:36],
                        [label.centerXAnchor constraintEqualToAnchor:pill.centerXAnchor],
                        [label.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor],
                        [label.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:20],
                        [label.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-20],
                    ]];

                    [UIView animateWithDuration:0.3 animations:^{ pill.alpha = 1; }];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [UIView animateWithDuration:0.3 animations:^{ pill.alpha = 0; } completion:^(BOOL f) {
                            [pill removeFromSuperview];
                        }];
                    });
                }
            }
        });
        return;
    }
    orig_applyUpdates(self, _cmd, updates, completion, userAccess);
}

// ============ LOCAL DELETE TRACKING ============

static void (*orig_removeMutation_execute)(id self, SEL _cmd, id handler, id pkg);
static void new_removeMutation_execute(id self, SEL _cmd, id handler, id pkg) {
    sciLocalDeleteInProgress = YES;
    orig_removeMutation_execute(self, _cmd, handler, pkg);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        sciLocalDeleteInProgress = NO;
    });
}

// ============ VISUAL INDICATOR ============

static NSString * _Nullable sciGetCellServerId(id cell) {
    @try {
        Ivar vmIvar = class_getInstanceVariable([cell class], "_viewModel");
        if (!vmIvar) return nil;
        id vm = object_getIvar(cell, vmIvar);
        if (!vm) return nil;

        SEL metaSel = NSSelectorFromString(@"messageMetadata");
        if (![vm respondsToSelector:metaSel]) return nil;
        id meta = ((id(*)(id,SEL))objc_msgSend)(vm, metaSel);
        if (!meta) return nil;

        Ivar keyIvar = class_getInstanceVariable([meta class], "_key");
        if (!keyIvar) return nil;
        id keyObj = object_getIvar(meta, keyIvar);
        if (!keyObj) return nil;

        Ivar sidIvar = class_getInstanceVariable([keyObj class], "_serverId");
        if (!sidIvar) return nil;
        NSString *serverId = object_getIvar(keyObj, sidIvar);
        return [serverId isKindOfClass:[NSString class]] ? serverId : nil;
    } @catch(id e) {}
    return nil;
}

// Hide trailing action buttons (forward, share, AI, etc.) on preserved cells —
// they don't work on preserved messages and overlap the "Unsent" label.
// _tappableAccessoryViews holds the inner tap targets; their visible wrapper
// (gray circle) is the closest squarish ancestor.

static BOOL sciCellIsPreserved(id cell) {
    NSString *sid = sciGetCellServerId(cell);
    return sid && [sciGetPreservedIds() containsObject:sid];
}

// Returns the closest squarish ancestor (32-60 pt, roughly equal width/height),
// which is the visible button wrapper. Falls back to the view itself.
static UIView *sciFindAccessoryWrapper(UIView *view) {
    UIView *cur = view;
    while (cur && cur.superview) {
        CGRect f = cur.frame;
        if (f.size.width >= 32 && f.size.width <= 60 &&
            fabs(f.size.width - f.size.height) < 4) {
            return cur;
        }
        cur = cur.superview;
    }
    return view;
}

static void sciSetTrailingButtonsHidden(UIView *cell, BOOL hidden) {
    if (!cell) return;
    Ivar accIvar = class_getInstanceVariable([cell class], "_tappableAccessoryViews");
    if (!accIvar) return;
    id accViews = object_getIvar(cell, accIvar);
    if (![accViews isKindOfClass:[NSArray class]]) return;
    for (UIView *v in (NSArray *)accViews) {
        if (![v isKindOfClass:[UIView class]]) continue;
        UIView *wrapper = sciFindAccessoryWrapper(v);
        wrapper.hidden = hidden;
        if (wrapper != v) v.hidden = hidden;
    }
}

static void (*orig_addTappableAccessoryView)(id self, SEL _cmd, id view);
static void new_addTappableAccessoryView(id self, SEL _cmd, id view) {
    orig_addTappableAccessoryView(self, _cmd, view);
    if (sciIndicateUnsentEnabled() && sciCellIsPreserved(self)) {
        if ([view isKindOfClass:[UIView class]]) {
            UIView *wrapper = sciFindAccessoryWrapper((UIView *)view);
            wrapper.hidden = YES;
            if (wrapper != view) ((UIView *)view).hidden = YES;
        }
    }
}

static void sciUpdateCellIndicator(id cell) {
    UIView *view = (UIView *)cell;
    UIView *oldIndicator = [view viewWithTag:SCI_PRESERVED_TAG];
    Ivar bubbleIvar = class_getInstanceVariable([cell class], "_messageContentContainerView");
    UIView *bubble = bubbleIvar ? object_getIvar(cell, bubbleIvar) : nil;

    if (!sciIndicateUnsentEnabled()) {
        if (oldIndicator) [oldIndicator removeFromSuperview];
        sciSetTrailingButtonsHidden(view, NO);
        return;
    }

    NSString *serverId = sciGetCellServerId(cell);
    BOOL isPreserved = serverId && [sciGetPreservedIds() containsObject:serverId];

    if (!isPreserved) {
        if (oldIndicator) [oldIndicator removeFromSuperview];
        sciSetTrailingButtonsHidden(view, NO);
        return;
    }

    sciSetTrailingButtonsHidden(view, YES);

    if (oldIndicator) return;

    UIView *parent = bubble ?: view;
    UILabel *label = [[UILabel alloc] init];
    label.tag = SCI_PRESERVED_TAG;
    label.text = @"Unsent";
    label.font = [UIFont italicSystemFontOfSize:10];
    label.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:4],
        [label.centerYAnchor constraintEqualToAnchor:parent.centerYAnchor],
    ]];
}

static void (*orig_configureCell)(id self, SEL _cmd, id vm, id ringSpec, id launcherSet);
static void new_configureCell(id self, SEL _cmd, id vm, id ringSpec, id launcherSet) {
    orig_configureCell(self, _cmd, vm, ringSpec, launcherSet);
    sciUpdateCellIndicator(self);
}

static void (*orig_cellLayoutSubviews)(id self, SEL _cmd);
static void new_cellLayoutSubviews(id self, SEL _cmd) {
    orig_cellLayoutSubviews(self, _cmd);
    sciUpdateCellIndicator(self);
}

// ============ ACTION LOG TRACKING ============
//
// IGDirectThreadActionLog is the local data-model class for "X liked a
// message" thread entries. IG instantiates one whenever an action log row
// is created — reaction add/remove, theme change, etc. We hook its full
// init, grab the message ID via the messageId getter, and store the class
// name in our content-class map. Later when a remove for that ID arrives,
// the consume path recognizes it as bookkeeping and skips preserving it.
static id (*orig_actionLogFullInit)(id, SEL, id, id, id, id, id, BOOL, BOOL, id);
static id new_actionLogFullInit(id self, SEL _cmd,
                                 id message, id title, id textAttributes, id textParts,
                                 id actionLogType, BOOL collapsible, BOOL hidden, id genAIMetadata) {
    id result = orig_actionLogFullInit(self, _cmd, message, title, textAttributes, textParts,
                                        actionLogType, collapsible, hidden, genAIMetadata);
    @try {
        SEL midSel = @selector(messageId);
        if ([result respondsToSelector:midSel]) {
            id mid = ((id(*)(id, SEL))objc_msgSend)(result, midSel);
            if ([mid isKindOfClass:[NSString class]]) {
                sciTrackInsertedMessage(mid, @"IGDirectThreadActionLog");
            }
        }
    } @catch(id e) {}
    return result;
}

// ============ RUNTIME HOOKS ============

%ctor {
    // Action log entries (e.g. "X liked a message") — record their message IDs
    // when IG creates them so we can later recognize a remove for those IDs as
    // action-log bookkeeping rather than a real unsend.
    Class actionLogCls = NSClassFromString(@"IGDirectThreadActionLog");
    if (actionLogCls) {
        SEL fullInit = NSSelectorFromString(@"initWithMessage:title:textAttributes:textParts:actionLogType:collapsible:hidden:genAIMetadata:");
        if (class_getInstanceMethod(actionLogCls, fullInit))
            MSHookMessageEx(actionLogCls, fullInit, (IMP)new_actionLogFullInit, (IMP *)&orig_actionLogFullInit);
    }

    Class msgUpdateClass = NSClassFromString(@"IGDirectMessageUpdate");
    if (msgUpdateClass) {
        MSHookMessageEx(object_getClass(msgUpdateClass), @selector(alloc),
                        (IMP)new_msgUpdate_alloc, (IMP *)&orig_msgUpdate_alloc);
    }


    Class cacheClass = NSClassFromString(@"IGDirectCacheUpdatesApplicator");
    if (cacheClass) {
        SEL sel = NSSelectorFromString(@"_applyThreadUpdates:completion:userAccess:");
        if (class_getInstanceMethod(cacheClass, sel))
            MSHookMessageEx(cacheClass, sel, (IMP)new_applyUpdates, (IMP *)&orig_applyUpdates);
    }

    Class cellClass = NSClassFromString(@"IGDirectMessageCell");
    if (cellClass) {
        SEL configSel = NSSelectorFromString(@"configureWithViewModel:ringViewSpecFactory:launcherSet:");
        if (class_getInstanceMethod(cellClass, configSel))
            MSHookMessageEx(cellClass, configSel,
                            (IMP)new_configureCell, (IMP *)&orig_configureCell);

        SEL layoutSel = @selector(layoutSubviews);
        MSHookMessageEx(cellClass, layoutSel,
                        (IMP)new_cellLayoutSubviews, (IMP *)&orig_cellLayoutSubviews);

        SEL addAccSel = NSSelectorFromString(@"_addTappableAccessoryView:");
        if (class_getInstanceMethod(cellClass, addAccSel))
            MSHookMessageEx(cellClass, addAccSel,
                            (IMP)new_addTappableAccessoryView, (IMP *)&orig_addTappableAccessoryView);
    }

    Class removeMutationClass = NSClassFromString(@"IGDirectMessageOutgoingUpdateRemoveMessagesMutationProcessor");
    if (removeMutationClass) {
        SEL execSel = NSSelectorFromString(@"executeWithResultHandler:accessoryPackage:");
        if (class_getInstanceMethod(removeMutationClass, execSel))
            MSHookMessageEx(removeMutationClass, execSel,
                            (IMP)new_removeMutation_execute, (IMP *)&orig_removeMutation_execute);
    }

    if (![SCIUtils getBoolPref:@"indicate_unsent_messages"]) {
        sciClearPreservedIds();
    }
}
