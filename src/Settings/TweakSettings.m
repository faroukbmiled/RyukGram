#import "TweakSettings.h"
#import "SCISettingsBackup.h"
#import "SCIExcludedChatsViewController.h"
#import "../Features/StoriesAndMessages/SCIExcludedThreads.h"
#import "../Features/StoriesAndMessages/SCIExcludedStoryUsers.h"
#import "SCIExcludedStoryUsersViewController.h"
#import "SCIEmbedDomainViewController.h"

@implementation SCITweakSettings

// MARK: - Sections

///
/// This returns an array of sections, with each section consisting of a dictionary
///
/// `"title"`: The section title (leave blank for no title)
///
/// `"rows"`: An array of **SCISetting** classes, potentially containing a "navigationCellWithTitle" initializer to allow for nested setting pages.
///
/// `"footer`: The section footer (leave blank for no footer)

+ (NSArray *)sections {
    return @[
        @{
            @"header": @"",
            @"rows": @[
                [SCISetting linkCellWithTitle:@"RyukGram on GitHub" subtitle:[NSString stringWithFormat:@"%@ — view source, report issues, see releases", SCIVersionString] imageUrl:@"https://github.com/faroukbmiled.png" url:@"https://github.com/faroukbmiled/RyukGram"]
            ]
        },
        @{
            @"header": @"",
            @"rows": @[
                [SCISetting navigationCellWithTitle:@"General"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"gear"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide ads" subtitle:@"Removes all ads from the Instagram app" defaultsKey:@"hide_ads"],
                                                [SCISetting switchCellWithTitle:@"Hide Meta AI" subtitle:@"Hides the meta ai buttons/functionality within the app" defaultsKey:@"hide_meta_ai"],
                                                [SCISetting switchCellWithTitle:@"Do not save recent searches" subtitle:@"Search bars will no longer save your recent searches" defaultsKey:@"no_recent_searches"],
                                                [SCISetting switchCellWithTitle:@"Copy description" subtitle:@"Copy description text fields by long-pressing on them" defaultsKey:@"copy_description"],
                                                [SCISetting switchCellWithTitle:@"Profile copy button" subtitle:@"Adds a button next to the burger menu on profiles to copy username, name or bio" defaultsKey:@"profile_copy_button"],
                                                [SCISetting switchCellWithTitle:@"Use detailed color picker" subtitle:@"Long press on the eyedropper tool in stories to customize the text color more precisely" defaultsKey:@"detailed_color_picker"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Browser",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Open links in external browser" subtitle:@"Opens links in Safari instead of Instagram's in-app browser" defaultsKey:@"open_links_external"],
                                                [SCISetting switchCellWithTitle:@"Strip tracking from links" subtitle:@"Removes Instagram tracking wrappers (l.instagram.com) and UTM/fbclid params from URLs" defaultsKey:@"strip_browser_tracking"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Sharing",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Replace domain in shared links" subtitle:@"Rewrites copied/shared links to use an embed-friendly domain for previews in Discord, Telegram, etc." defaultsKey:@"embed_links"],
                                                ({
                                                    SCISetting *s = [SCISetting buttonCellWithTitle:@"Embed domain"
                                                                       subtitle:@""
                                                                           icon:[SCISymbol symbolWithName:@"globe"]
                                                                         action:^(void) {
                                                        UIWindow *win = nil;
                                                        for (UIWindow *w in [UIApplication sharedApplication].windows)
                                                            if (w.isKeyWindow) { win = w; break; }
                                                        UIViewController *top = win.rootViewController;
                                                        while (top.presentedViewController) top = top.presentedViewController;
                                                        if ([top isKindOfClass:[UINavigationController class]])
                                                            [(UINavigationController *)top pushViewController:[SCIEmbedDomainViewController new] animated:YES];
                                                        else if (top.navigationController)
                                                            [top.navigationController pushViewController:[SCIEmbedDomainViewController new] animated:YES];
                                                    }];
                                                    s.dynamicTitle = ^{ return [NSString stringWithFormat:@"Embed domain: %@", [SCIUtils getStringPref:@"embed_link_domain"] ?: @"kkinstagram.com"]; };
                                                    s;
                                                }),
                                                [SCISetting switchCellWithTitle:@"Strip tracking params" subtitle:@"Removes igsh, utm_source, and other tracking parameters from shared links" defaultsKey:@"strip_tracking_params"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Comments",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Copy comment text" subtitle:@"Adds a copy option to the comment long-press menu" defaultsKey:@"copy_comment"],
                                                [SCISetting switchCellWithTitle:@"Download GIF comments" subtitle:@"Adds a download option for GIF comments" defaultsKey:@"download_gif_comment"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Notes",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide notes tray" subtitle:@"Hides the notes tray in the dm inbox" defaultsKey:@"hide_notes_tray"],
                                                [SCISetting switchCellWithTitle:@"Hide friends map" subtitle:@"Hides the friends map icon in the notes tray" defaultsKey:@"hide_friends_map"],
                                                [SCISetting switchCellWithTitle:@"Enable note theming" subtitle:@"Enables the ability to use the notes theme picker" defaultsKey:@"enable_notes_customization"],
                                                [SCISetting switchCellWithTitle:@"Custom note themes" subtitle:@"Provides an option to set custom emojis and background/text colors" defaultsKey:@"custom_note_themes"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Focus/distractions",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"No suggested users" subtitle:@"Hides all suggested users for you to follow, outside your feed" defaultsKey:@"no_suggested_users"],
                                                [SCISetting switchCellWithTitle:@"No suggested chats" subtitle:@"Hides the suggested broadcast channels in direct messages" defaultsKey:@"no_suggested_chats"],
                                                [SCISetting switchCellWithTitle:@"Hide explore posts grid" subtitle:@"Hides the grid of suggested posts on the explore/search tab" defaultsKey:@"hide_explore_grid"],
                                                [SCISetting switchCellWithTitle:@"Hide trending searches" subtitle:@"Hides the trending searches under the explore search bar" defaultsKey:@"hide_trending_searches"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Experimental features",
                                            @"footer": @"These features rely on hidden Instagram flags and may not work on all accounts or versions.",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Enable liquid glass buttons" subtitle:@"Enables experimental liquid glass buttons" defaultsKey:@"liquid_glass_buttons" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Enable liquid glass surfaces" subtitle:@"Enables liquid glass for other elements" defaultsKey:@"liquid_glass_surfaces" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Enable teen app icons" subtitle:@"Hold down on the Instagram logo to change the app icon" defaultsKey:@"teen_app_icons" requiresRestart:YES]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Feed"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"rectangle.stack"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide stories tray" subtitle:@"Hides the story tray at the top and within your feed" defaultsKey:@"hide_stories_tray"],
                                                [SCISetting switchCellWithTitle:@"Hide entire feed" subtitle:@"Removes all content from your home feed, including posts" defaultsKey:@"hide_entire_feed"],
                                                [SCISetting switchCellWithTitle:@"No suggested posts" subtitle:@"Removes suggested posts from your feed" defaultsKey:@"no_suggested_post"],
                                                [SCISetting switchCellWithTitle:@"No suggested for you" subtitle:@"Hides suggested accounts for you to follow" defaultsKey:@"no_suggested_account"],
                                                [SCISetting switchCellWithTitle:@"No suggested reels" subtitle:@"Hides suggested reels to watch" defaultsKey:@"no_suggested_reels"],
                                                [SCISetting switchCellWithTitle:@"No suggested threads posts" subtitle:@"Hides suggested threads posts" defaultsKey:@"no_suggested_threads"],
                                                [SCISetting switchCellWithTitle:@"Disable video autoplay" subtitle:@"Prevents videos on your feed from playing automatically" defaultsKey:@"disable_feed_autoplay" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Hide repost button" subtitle:@"Hides the repost button on feed posts" defaultsKey:@"hide_feed_repost" requiresRestart:YES]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Reels"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"film.stack"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting menuCellWithTitle:@"Tap Controls" subtitle:@"Change what happens when you tap on a reel" menu:[self menus][@"reels_tap_control"]],
                                                [SCISetting switchCellWithTitle:@"Always show progress scrubber" subtitle:@"Forces the progress bar to appear on every reel" defaultsKey:@"reels_show_scrubber"],
                                                [SCISetting switchCellWithTitle:@"Disable auto-unmuting reels" subtitle:@"Prevents reels from unmuting when the volume/silent button is pressed" defaultsKey:@"disable_auto_unmuting_reels" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Confirm reel refresh" subtitle:@"Shows an alert when you trigger a reels refresh" defaultsKey:@"refresh_reel_confirm"],
                                                [SCISetting switchCellWithTitle:@"Unlock password-locked reels" subtitle:@"Shows buttons to reveal and auto-fill the password on locked reels" defaultsKey:@"unlock_password_reels"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Hiding",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide reels header" subtitle:@"Hides the top navigation bar when watching reels" defaultsKey:@"hide_reels_header"],
                                                [SCISetting switchCellWithTitle:@"Hide repost button" subtitle:@"Hides the repost button on the reels sidebar" defaultsKey:@"hide_reels_repost" requiresRestart:YES]
                                            ]
                                        },
                                        @{
                                            @"header": @"Limits",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Disable scrolling reels" subtitle:@"Prevents reels from being scrolled to the next video" defaultsKey:@"disable_scrolling_reels" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Prevent doom scrolling" subtitle:@"Limits the amount of reels available to scroll at any given time, and prevents refreshing" defaultsKey:@"prevent_doom_scrolling"],
                                                [SCISetting stepperCellWithTitle:@"Doom scrolling limit" subtitle:@"Only loads %@ %@" defaultsKey:@"doom_scrolling_reel_count" min:1 max:100 step:1 label:@"reels" singularLabel:@"reel"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Saving"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"tray.and.arrow.down"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Download feed posts" subtitle:@"Long-press with finger(s) to download posts in the home tab" defaultsKey:@"dw_feed_posts"],
                                                [SCISetting switchCellWithTitle:@"Download reels" subtitle:@"Long-press with finger(s) on a reel to download" defaultsKey:@"dw_reels"],
                                                [SCISetting switchCellWithTitle:@"Download stories" subtitle:@"Long-press with finger(s) while viewing someone's story to download" defaultsKey:@"dw_story"],
                                                [SCISetting switchCellWithTitle:@"Save profile picture" subtitle:@"On someone's profile, click their profile picture to enlarge it, then hold to download" defaultsKey:@"save_profile"]
                                            ]
                                        },
                                        @{
                                            @"header": @"Download method",
                                            @"footer": @"When \"Save to RyukGram album\" is on, downloads and share-sheet \"Save to Photos\" picks are routed into a dedicated \"RyukGram\" album in your Photos library.",
                                            @"rows": @[
                                                [SCISetting menuCellWithTitle:@"Download method" subtitle:@"How to trigger downloads" menu:[self menus][@"dw_method"]],
                                                [SCISetting menuCellWithTitle:@"Save action" subtitle:@"What happens after downloading" menu:[self menus][@"dw_save_action"]],
                                                [SCISetting switchCellWithTitle:@"Confirm before download" subtitle:@"Show a confirmation dialog before starting a download" defaultsKey:@"dw_confirm"],
                                                [SCISetting switchCellWithTitle:@"Save to RyukGram album" subtitle:@"Route saves into a dedicated album in Photos instead of the camera roll root" defaultsKey:@"save_to_ryukgram_album"]
                                            ]
                                        },
                                        @{
                                            @"header": @"Customize gestures",
                                            @"footer": @"Only applies when download method is set to \"Long-press gesture\"",
                                            @"rows": @[
                                                [SCISetting stepperCellWithTitle:@"Finger count for long-press" subtitle:@"Downloads with %@ %@" defaultsKey:@"dw_finger_count" min:1 max:5 step:1 label:@"fingers" singularLabel:@"finger"],
                                                [SCISetting stepperCellWithTitle:@"Long-press hold time" subtitle:@"Press finger(s) for %@ %@" defaultsKey:@"dw_finger_duration" min:0 max:10 step:0.25 label:@"sec" singularLabel:@"sec"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Stories"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"circle.dashed"]
                                        navSections:@[@{
                                            @"header": @"Seen receipts",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Disable story seen receipt" subtitle:@"Hides the notification for others when you view their story" defaultsKey:@"no_seen_receipt"],
                                                [SCISetting switchCellWithTitle:@"Keep stories visually unseen" subtitle:@"Prevents stories from visually marking as seen in the tray (keeps colorful ring)" defaultsKey:@"no_seen_visual"],
                                                [SCISetting switchCellWithTitle:@"Mark seen on story like" subtitle:@"Marks a story as seen the moment you tap the heart, even with seen blocking on" defaultsKey:@"seen_on_story_like"],
                                                [SCISetting menuCellWithTitle:@"Manual seen button mode" subtitle:@"Button = single-tap mark seen. Toggle = tap toggles story read receipts on/off (eye fills blue when on)" menu:[self menus][@"story_seen_mode"]],
                                            ]
                                        },
                                        @{
                                            @"header": @"Playback",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Stop story auto-advance" subtitle:@"Stories won't auto-skip to the next one when the timer ends. Tap to advance manually" defaultsKey:@"stop_story_auto_advance"],
                                                [SCISetting switchCellWithTitle:@"Advance when marking as seen" subtitle:@"Tapping the eye button to mark a story as seen advances to the next story automatically" defaultsKey:@"advance_on_mark_seen"],
                                                [SCISetting switchCellWithTitle:@"Advance on story like" subtitle:@"Liking a story automatically advances to the next one after a short delay" defaultsKey:@"advance_on_story_like"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Story user list",
                                            @"footer": @"Block all: all stories blocked — listed users are exceptions.\nBlock selected: only listed users are blocked — everything else is normal.\nBoth lists are saved independently.",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Enable story user list" subtitle:@"Master toggle. When off, the list is ignored" defaultsKey:@"enable_story_user_exclusions"],
                                                [SCISetting menuCellWithTitle:@"Blocking mode" subtitle:@"Which stories get seen-receipt blocking" menu:[self menus][@"story_blocking_mode"]],
                                                [SCISetting switchCellWithTitle:@"Quick list button in stories" subtitle:@"Shows an eye button on stories to add/remove users from the list. Off = use the 3-dot menu or long-press only" defaultsKey:@"story_excluded_show_unexclude_eye"],
                                                ({
                                                    SCISetting *s = [SCISetting buttonCellWithTitle:@"Manage list"
                                                                       subtitle:@"Search, sort, swipe to remove"
                                                                           icon:[SCISymbol symbolWithName:@"list.bullet.rectangle"]
                                                                         action:^(void) {
                                                        UIWindow *win = nil;
                                                        for (UIWindow *w in [UIApplication sharedApplication].windows) {
                                                            if (w.isKeyWindow) { win = w; break; }
                                                        }
                                                        UIViewController *top = win.rootViewController;
                                                        while (top.presentedViewController) top = top.presentedViewController;
                                                        if ([top isKindOfClass:[UINavigationController class]]) {
                                                            [(UINavigationController *)top pushViewController:[SCIExcludedStoryUsersViewController new] animated:YES];
                                                        } else if (top.navigationController) {
                                                            [top.navigationController pushViewController:[SCIExcludedStoryUsersViewController new] animated:YES];
                                                        }
                                                    }];
                                                    s.dynamicTitle = ^{ return [NSString stringWithFormat:@"Manage list (%lu)", (unsigned long)[SCIExcludedStoryUsers count]]; };
                                                    s;
                                                }),
                                            ]
                                        },
                                        @{
                                            @"header": @"Audio",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Story audio toggle" subtitle:@"Adds a speaker button to the story overlay to unmute/mute audio. Also available in the 3-dot menu" defaultsKey:@"story_audio_toggle"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Other",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Disable instants creation" subtitle:@"Hides the functionality to create/send instants" defaultsKey:@"disable_instants_creation" requiresRestart:YES]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Messages"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"bubble.left.and.bubble.right"]
                                        navSections:@[@{
                                            @"header": @"Threads",
                                            @"rows": @[
                                                [SCISetting navigationCellWithTitle:@"Keep deleted messages"
                                                                           subtitle:@"Preserve messages that others unsend"
                                                                               icon:nil
                                                                        navSections:@[@{
                                                                            @"header": @"",
                                                                            @"footer": @"⚠️ WARNING: Pull-to-refresh in the DMs tab CLEARS all preserved messages. Enable \"Warn before clearing on refresh\" below to get a confirmation dialog before this happens.",
                                                                            @"rows": @[
                                                                                [SCISetting switchCellWithTitle:@"Keep deleted messages" subtitle:@"Preserves messages that others unsend" defaultsKey:@"keep_deleted_message"],
                                                                                [SCISetting switchCellWithTitle:@"Indicate unsent messages" subtitle:@"Shows an \"Unsent\" label on preserved messages" defaultsKey:@"indicate_unsent_messages"],
                                                                                [SCISetting switchCellWithTitle:@"Unsent message notification" subtitle:@"Shows a notification pill when a message is unsent" defaultsKey:@"unsent_message_toast"],
                                                                                [SCISetting switchCellWithTitle:@"Warn before clearing on refresh" subtitle:@"Show a confirmation dialog when pulling to refresh the DMs tab if preserved messages would be cleared" defaultsKey:@"warn_refresh_clears_preserved"],
                                                                            ]
                                                                        }]
                                                ],
                                                [SCISetting navigationCellWithTitle:@"Read receipts"
                                                                           subtitle:@"Control when messages are marked as seen"
                                                                               icon:nil
                                                                        navSections:@[@{
                                                                            @"header": @"",
                                                                            @"rows": @[
                                                                                [SCISetting switchCellWithTitle:@"Manually mark messages as seen" subtitle:@"Adds a button to DM threads to mark messages as seen" defaultsKey:@"remove_lastseen"],
                                                                                [SCISetting menuCellWithTitle:@"Read receipt mode" subtitle:@"How the seen button behaves" menu:[self menus][@"seen_mode"]],
                                                                                [SCISetting switchCellWithTitle:@"Auto mark seen on interact" subtitle:@"Locally marks messages as seen when you send any message" defaultsKey:@"seen_auto_on_interact"],
                                                                                [SCISetting switchCellWithTitle:@"Auto mark seen on typing" subtitle:@"Marks messages as seen the moment you start typing in a DM (works even when typing status is hidden)" defaultsKey:@"seen_auto_on_typing"],
                                                                                                                                                            ]
                                                                        }]
                                                ],
                                                [SCISetting switchCellWithTitle:@"Disable typing status" subtitle:@"Prevents the typing indicator from being shown to others when you're typing in DMs" defaultsKey:@"disable_typing_status"],
                                                [SCISetting switchCellWithTitle:@"Hide reels blend button" subtitle:@"Hides the button in DMs to open a reels blend" defaultsKey:@"hide_reels_blend"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Chat list",
                                            @"footer": @"Block all: all chats blocked — listed chats are exceptions.\nBlock selected: only listed chats are blocked — everything else is normal.\nBoth lists are saved independently. Long-press a chat in the inbox to add or remove.",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Enable chat list" subtitle:@"Master toggle. When off, the list is ignored" defaultsKey:@"enable_chat_exclusions"],
                                                [SCISetting menuCellWithTitle:@"Blocking mode" subtitle:@"Which chats get read-receipt blocking" menu:[self menus][@"chat_blocking_mode"]],
                                                ({
    SCISetting *s = [SCISetting switchCellWithTitle:@"" subtitle:@"" defaultsKey:@"exclusions_default_keep_deleted"];
    s.dynamicTitle = ^{
        BOOL bs = [[SCIUtils getStringPref:@"chat_blocking_mode"] isEqualToString:@"block_selected"];
        return bs ? @"Block keep-deleted for unlisted chats"
                  : @"Block keep-deleted for excluded chats";
    };
    s.subtitle = @"Each chat can override this in the list";
    s;
}),
                                                [SCISetting switchCellWithTitle:@"Quick list button in chats" subtitle:@"Shows a button in DM threads to add/remove chats from the list. Long-press for more options" defaultsKey:@"chat_quick_list_button"],
                                                ({
                                                    SCISetting *s = [SCISetting buttonCellWithTitle:@"Manage list"
                                                                       subtitle:@"Search, sort, swipe to remove or toggle keep-deleted"
                                                                           icon:[SCISymbol symbolWithName:@"list.bullet.rectangle"]
                                                                         action:^(void) {
                                                        UIWindow *win = nil;
                                                        for (UIWindow *w in [UIApplication sharedApplication].windows) {
                                                            if (w.isKeyWindow) { win = w; break; }
                                                        }
                                                        UIViewController *top = win.rootViewController;
                                                        while (top.presentedViewController) top = top.presentedViewController;
                                                        if ([top isKindOfClass:[UINavigationController class]]) {
                                                            [(UINavigationController *)top pushViewController:[SCIExcludedChatsViewController new] animated:YES];
                                                        } else if (top.navigationController) {
                                                            [top.navigationController pushViewController:[SCIExcludedChatsViewController new] animated:YES];
                                                        }
                                                    }];
                                                    s.dynamicTitle = ^{ return [NSString stringWithFormat:@"Manage list (%lu)", (unsigned long)[SCIExcludedThreads count]]; };
                                                    s;
                                                }),
                                            ]
                                        },
                                        @{
                                            @"header": @"Voice messages",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Send audio as file" subtitle:@"Adds an 'Audio File' option to the plus menu in DMs to send audio files as voice messages" defaultsKey:@"send_audio_as_file"],
                                                [SCISetting switchCellWithTitle:@"Download voice messages" subtitle:@"Adds a 'Download' option to the long-press menu on voice messages to save them as M4A audio" defaultsKey:@"download_audio_message"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Visual messages",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Unlimited replay of visual messages" subtitle:@"Replays direct visual messages normal/once stories unlimited times (toggle with image check icon)" defaultsKey:@"unlimited_replay"],
                                                [SCISetting switchCellWithTitle:@"Disable view-once limitations" subtitle:@"Makes view-once messages behave like normal visual messages (loopable/pauseable)" defaultsKey:@"disable_view_once_limitations"],
                                                [SCISetting switchCellWithTitle:@"Disable screenshot detection" subtitle:@"Removes the screenshot-prevention features for visual messages in DMs" defaultsKey:@"remove_screenshot_alert"],
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Navigation"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"hand.draw.fill"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting menuCellWithTitle:@"Icon order" subtitle:@"The order of the icons on the bottom navigation bar" menu:[self menus][@"nav_icon_ordering"]],
                                                [SCISetting menuCellWithTitle:@"Swipe between tabs" subtitle:@"Lets you swipe to switch between navigation bar tabs" menu:[self menus][@"swipe_nav_tabs"]],
                                            ]
                                        },
                                        @{
                                            @"header": @"Hiding tabs",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide feed tab" subtitle:@"Hides the feed/home tab on the bottom navigation bar" defaultsKey:@"hide_feed_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Hide explore tab" subtitle:@"Hides the explore/search tab on the bottom navigation bar" defaultsKey:@"hide_explore_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Hide reels tab" subtitle:@"Hides the reels tab on the bottom navigation bar" defaultsKey:@"hide_reels_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Hide create tab" subtitle:@"Hides the create tab on the bottom navigation bar" defaultsKey:@"hide_create_tab" requiresRestart:YES]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Confirm actions"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"checkmark"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Confirm like: Posts/Stories" subtitle:@"Shows an alert when you click the like button on posts or stories to confirm the like" defaultsKey:@"like_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm like: Reels" subtitle:@"Shows an alert when you click the like button on reels to confirm the like" defaultsKey:@"like_confirm_reels"]
                                            ]
                                        },
                                        @{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Confirm follow" subtitle:@"Shows an alert when you click the follow button to confirm the follow" defaultsKey:@"follow_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm repost" subtitle:@"Shows an alert when you click the repost button to confirm before resposting" defaultsKey:@"repost_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm call" subtitle:@"Shows an alert when you click the audio/video call button to confirm before calling" defaultsKey:@"call_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm voice messages" subtitle:@"Shows an alert to confirm before sending a voice message" defaultsKey:@"voice_message_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm follow requests" subtitle:@"Shows an alert when you accept/decline a follow request" defaultsKey:@"follow_request_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm shh mode" subtitle:@"Shows an alert to confirm before toggling disappearing messages" defaultsKey:@"shh_mode_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm posting comment" subtitle:@"Shows an alert when you click the post comment button to confirm" defaultsKey:@"post_comment_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm changing theme" subtitle:@"Shows an alert when you change a chat theme to confirm" defaultsKey:@"change_direct_theme_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm sticker interaction" subtitle:@"Shows an alert when you click a sticker on someone's story to confirm the action" defaultsKey:@"sticker_interact_confirm"]
                                            ]
                                        }]
                ]
            ]
        },
        @{
            @"header": @"",
            @"rows": @[
                [SCISetting navigationCellWithTitle:@"Backup & Restore"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"arrow.up.arrow.down.square"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"footer": @"Export your RyukGram settings to a JSON file and import them later. Importing resets all settings to defaults before applying the imported values, and shows a preview before anything changes.",
                                            @"rows": @[
                                                [SCISetting buttonCellWithTitle:@"Export settings"
                                                                       subtitle:@"Save settings as a JSON file"
                                                                           icon:[SCISymbol symbolWithName:@"square.and.arrow.up"]
                                                                         action:^(void) { [SCISettingsBackup presentExport]; }
                                                ],
                                                [SCISetting buttonCellWithTitle:@"Import settings"
                                                                       subtitle:@"Load settings from a JSON file"
                                                                           icon:[SCISymbol symbolWithName:@"square.and.arrow.down"]
                                                                         action:^(void) { [SCISettingsBackup presentImport]; }
                                                ]
                                            ]
                                        }]
                ],
                // [SCISetting navigationCellWithTitle:@"Experimental"
                //                            subtitle:@""
                //                                icon:[SCISymbol symbolWithName:@"testtube.2"]
                //                         navSections:@[@{
                //                             @"header": @"Warning",
                //                             @"footer": @"These features are unstable and cause the Instagram app to crash unexpectedly.\n\nUse at your own risk!"
                //                         },
                //                         @{
                //                             @"header": @"",
                //                             @"rows": @[

                //                             ]
                //                         }
                //                         ]
                // ],
                [SCISetting navigationCellWithTitle:@"Advanced"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"gearshape.2"]
                                        navSections:@[@{
                                            @"header": @"Settings",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Enable tweak settings quick-access" subtitle:@"Hold on the home tab to open RyukGram settings" defaultsKey:@"settings_shortcut" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Show tweak settings on app launch" subtitle:@"Automatically opens settings when the app launches" defaultsKey:@"tweak_settings_app_launch"],
                                                [SCISetting switchCellWithTitle:@"Pause playback when opening settings" subtitle:@"Pauses any playing video/audio when settings opens" defaultsKey:@"settings_pause_playback"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Instagram",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Disable safe mode" subtitle:@"Prevents Instagram from resetting settings after crashes (at your own risk)" defaultsKey:@"disable_safe_mode"],
                                                [SCISetting buttonCellWithTitle:@"Reset onboarding state"
                                                                           subtitle:@""
                                                                               icon:nil
                                                                             action:^(void) { [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SCInstaFirstRun"]; [SCIUtils showRestartConfirmation];}
                                                ],
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Debug"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"ladybug"]
                                        navSections:@[@{
                                            @"header": @"FLEX",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Enable FLEX gesture" subtitle:@"Hold 5 fingers on the screen to open FLEX" defaultsKey:@"flex_instagram"],
                                                [SCISetting switchCellWithTitle:@"Open FLEX on app launch" subtitle:@"Opens FLEX when the app launches" defaultsKey:@"flex_app_launch"],
                                                [SCISetting switchCellWithTitle:@"Open FLEX on app focus" subtitle:@"Opens FLEX when the app is focused" defaultsKey:@"flex_app_start"]
                                            ]
                                        },
                                        @{
                                            @"header": @"_ Example",
                                            @"rows": @[
                                                [SCISetting staticCellWithTitle:@"Static Cell" subtitle:@"" icon:[SCISymbol symbolWithName:@"tablecells"]],
                                                [SCISetting switchCellWithTitle:@"Switch Cell" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell"],
                                                [SCISetting switchCellWithTitle:@"Switch Cell (Restart)" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell_restart" requiresRestart:YES],
                                                [SCISetting stepperCellWithTitle:@"Stepper cell" subtitle:@"I have %@%@" defaultsKey:@"test_stepper_cell" min:-10 max:1000 step:5.5 label:@"$" singularLabel:@"$"],
                                                [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using icon" icon:[SCISymbol symbolWithName:@"link" color:[UIColor systemTealColor] size:20.0] url:@"https://google.com"],
                                                [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using image" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://google.com"],
                                                [SCISetting buttonCellWithTitle:@"Button Cell"
                                                                           subtitle:@""
                                                                               icon:[SCISymbol symbolWithName:@"oval.inset.filled"]
                                                                             action:^(void) { [SCIUtils showConfirmation:^(void){}]; }
                                                ],
                                                [SCISetting menuCellWithTitle:@"Menu Cell" subtitle:@"Change the value on the right" menu:[self menus][@"test"]],
                                                [SCISetting navigationCellWithTitle:@"Navigation Cell"
                                                                           subtitle:@""
                                                                               icon:[SCISymbol symbolWithName:@"rectangle.stack"]
                                                                        navSections:@[@{
                                                                            @"header": @"",
                                                                            @"rows": @[]
                                                                        }]
                                                ]
                                            ],
                                            @"footer": @"_ Example"
                                        }
                                        ]
                ]
            ]
        },
        @{
            @"header": @"Credits",
            @"rows": @[
                [SCISetting linkCellWithTitle:@"Ryuk" subtitle:@"Developer" imageUrl:@"https://github.com/faroukbmiled.png" url:@"https://github.com/faroukbmiled"],
                [SCISetting linkCellWithTitle:@"View Repo" subtitle:@"View the source code on GitHub" imageUrl:@"https://i.imgur.com/BBUNzeP.png" url:@"https://github.com/faroukbmiled/RyukGram"],
                [SCISetting linkCellWithTitle:@"SoCuul" subtitle:@"Original SCInsta developer" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://github.com/SoCuul/SCInsta"],
                [SCISetting linkCellWithTitle:@"Donate to SoCuul" subtitle:@"Support the original developer" icon:[SCISymbol symbolWithName:@"heart.circle.fill" color:[UIColor systemPinkColor] size:20.0] url:@"https://ko-fi.com/SoCuul"]
            ],
            @"footer": [NSString stringWithFormat:@"RyukGram %@\n\nInstagram v%@\n\nBased on SCInsta by SoCuul", SCIVersionString, [SCIUtils IGVersionString]]
        }
    ];
}


// MARK: - Title

///
/// This is the title displayed on the initial settings page view controller
///

+ (NSString *)title {
    return @"RyukGram Settings";
}


// MARK: - Menus

///
/// This returns a dictionary where each key corresponds to a certain menu that can be displayed.
/// Each "propertyList"  item is an NSDictionary containing the following items:
///
/// `"defaultsKey"`: The key to save the selected value under in NSUserDefaults
///
/// `"value"`: A unique string corresponding to the menu item which is selected
///
/// `"requiresRestart"`: (optional) Causes a popup to appear detailing you have to restart to use these features
///

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

+ (NSDictionary *)menus {
    return @{
        @"chat_blocking_mode": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Block all"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{ @"defaultsKey": @"chat_blocking_mode", @"value": @"block_all" }
            ],
            [UICommand commandWithTitle:@"Block selected"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{ @"defaultsKey": @"chat_blocking_mode", @"value": @"block_selected" }
            ]
        ]],

        @"story_blocking_mode": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Block all"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{ @"defaultsKey": @"story_blocking_mode", @"value": @"block_all" }
            ],
            [UICommand commandWithTitle:@"Block selected"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{ @"defaultsKey": @"story_blocking_mode", @"value": @"block_selected" }
            ]
        ]],

        @"story_seen_mode": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Button"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"story_seen_mode",
                                @"value": @"button"
                            }
            ],
            [UICommand commandWithTitle:@"Toggle"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"story_seen_mode",
                                @"value": @"toggle"
                            }
            ]
        ]],

        @"seen_mode": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Button"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"seen_mode",
                                @"value": @"button"
                            }
            ],
            [UICommand commandWithTitle:@"Toggle"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"seen_mode",
                                @"value": @"toggle"
                            }
            ]
        ]],

        @"dw_save_action": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Share sheet"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"dw_save_action",
                                @"value": @"share"
                            }
            ],
            [UICommand commandWithTitle:@"Save to Photos"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"dw_save_action",
                                @"value": @"photos"
                            }
            ]
        ]],

        @"dw_method": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Download button"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"dw_method",
                                @"value": @"button",
                                @"requiresRestart": @YES
                            }
            ],
            [UICommand commandWithTitle:@"Long-press gesture"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"dw_method",
                                @"value": @"gesture",
                                @"requiresRestart": @YES
                            }
            ]
        ]],

        @"reels_tap_control": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Default"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"reels_tap_control",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Pause/Play"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"reels_tap_control",
                                                    @"value": @"pause",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Mute/Unmute"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"reels_tap_control",
                                                    @"value": @"mute",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],

        @"nav_icon_ordering": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Default"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"nav_icon_ordering",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Classic"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"classic",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Standard"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"standard",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Alternate"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"alternate",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],
        @"swipe_nav_tabs": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Default"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"swipe_nav_tabs",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Enabled"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"swipe_nav_tabs",
                                                    @"value": @"enabled",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Disabled"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"swipe_nav_tabs",
                                                    @"value": @"disabled",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],

        @"test": [UIMenu menuWithChildren:@[
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"ABC"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"test_menu_cell",
                                                    @"value": @"abc"
                                                }
                                ],
                                [UICommand commandWithTitle:@"123"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"test_menu_cell",
                                                    @"value": @"123"
                                                }
                                ]
                            ]
            ],
            [UICommand commandWithTitle:@"Requires restart"
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"test_menu_cell",
                               @"value": @"requires_restart",
                               @"requiresRestart": @YES
                           }
            ],
        ]]
    };
}

#pragma clang diagnostic pop

@end
