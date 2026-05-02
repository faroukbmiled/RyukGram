#import "SCIActionMenu.h"

#pragma mark - SCIAction

@interface SCIAction ()
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite, nullable) NSString *subtitle;
@property (nonatomic, copy, readwrite, nullable) NSString *systemIconName;
@property (nonatomic, copy, readwrite, nullable) void (^handler)(void);
@property (nonatomic, copy, readwrite, nullable) NSArray<SCIAction *> *children;
@property (nonatomic, assign, readwrite) BOOL destructive;
@property (nonatomic, assign, readwrite) BOOL isSeparator;
@property (nonatomic, assign, readwrite) BOOL disabled;
@end

@implementation SCIAction

+ (instancetype)actionWithTitle:(NSString *)title
                           icon:(NSString *)icon
                        handler:(void(^)(void))handler {
    return [self actionWithTitle:title subtitle:nil icon:icon destructive:NO handler:handler];
}

+ (instancetype)actionWithTitle:(NSString *)title
                       subtitle:(NSString *)subtitle
                           icon:(NSString *)icon
                    destructive:(BOOL)destructive
                        handler:(void(^)(void))handler {
    SCIAction *a = [SCIAction new];
    a.title = title ?: @"";
    a.subtitle = subtitle;
    a.systemIconName = icon;
    a.handler = handler;
    a.destructive = destructive;
    return a;
}

+ (instancetype)actionWithTitle:(NSString *)title
                           icon:(NSString *)icon
                       children:(NSArray<SCIAction *> *)children {
    SCIAction *a = [SCIAction new];
    a.title = title ?: @"";
    a.systemIconName = icon;
    a.children = [children copy];
    return a;
}

+ (instancetype)separator {
    SCIAction *a = [SCIAction new];
    a.isSeparator = YES;
    return a;
}

+ (instancetype)headerWithTitle:(NSString *)title {
    SCIAction *a = [SCIAction new];
    a.title = title ?: @"";
    a.disabled = YES;
    return a;
}

@end


#pragma mark - SCIActionMenu

@implementation SCIActionMenu

+ (UIImage *)imageForIcon:(NSString *)name {
    if (!name.length) return nil;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];
    return [UIImage systemImageNamed:name withConfiguration:cfg];
}

// Convert SCIAction to UIMenuElement.
+ (UIMenuElement *)elementForAction:(SCIAction *)action {
    if (action.children.count) {
        NSMutableArray<UIMenuElement *> *kids = [NSMutableArray arrayWithCapacity:action.children.count];
        for (SCIAction *child in action.children) {
            UIMenuElement *el = [self elementForAction:child];
            if (el) [kids addObject:el];
        }
        return [UIMenu menuWithTitle:action.title
                               image:[self imageForIcon:action.systemIconName]
                          identifier:nil
                             options:0
                            children:kids];
    }

    UIAction *ua = [UIAction actionWithTitle:action.title
                                       image:[self imageForIcon:action.systemIconName]
                                  identifier:nil
                                     handler:^(__kindof UIAction * _Nonnull a) {
        if (action.handler) action.handler();
    }];

    if (@available(iOS 15.0, *)) {
        if (action.subtitle.length) ua.subtitle = action.subtitle;
    }
    if (action.destructive) ua.attributes = UIMenuElementAttributesDestructive;
    if (action.disabled) {
        if (@available(iOS 15.0, *)) {
            ua.attributes |= UIMenuElementAttributesDisabled;
        } else {
            ua.attributes = UIMenuElementAttributesDisabled;
        }
    }
    return ua;
}

+ (UIMenu *)buildMenuWithActions:(NSArray<SCIAction *> *)actions {
    return [self buildMenuWithActions:actions title:nil];
}

+ (UIMenu *)buildMenuWithActions:(NSArray<SCIAction *> *)actions title:(NSString *)title {
    // Header marker → first inline group's title (small grey caption).
    NSString *headerTitle = nil;
    NSArray<SCIAction *> *items = actions;
    if (actions.count > 0) {
        SCIAction *first = actions.firstObject;
        if (first.disabled && !first.handler && !first.isSeparator) {
            headerTitle = first.title;
            NSUInteger start = 1;
            if (start < actions.count && actions[start].isSeparator) start++;
            items = [actions subarrayWithRange:NSMakeRange(start, actions.count - start)];
        }
    }

    // Group actions between separators into inline submenus.
    NSMutableArray<UIMenuElement *> *top = [NSMutableArray array];
    NSMutableArray<UIMenuElement *> *currentGroup = [NSMutableArray array];
    __block BOOL isFirstFlush = YES;

    void (^flush)(void) = ^{
        if (currentGroup.count == 0) return;
        NSString *t = (isFirstFlush && headerTitle.length) ? headerTitle : @"";
        UIMenu *group = [UIMenu menuWithTitle:t
                                        image:nil
                                   identifier:nil
                                      options:UIMenuOptionsDisplayInline
                                     children:[currentGroup copy]];
        [top addObject:group];
        [currentGroup removeAllObjects];
        isFirstFlush = NO;
    };

    for (SCIAction *a in items) {
        if (a.isSeparator) {
            flush();
            continue;
        }
        UIMenuElement *el = [self elementForAction:a];
        if (el) [currentGroup addObject:el];
    }
    flush();

    return [UIMenu menuWithTitle:title ?: @""
                           image:nil
                      identifier:nil
                         options:0
                        children:[top copy]];
}

@end
