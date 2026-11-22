# [release] RyukGram v1.6.0

### 🆕 New features

#### Interface & theme

- Theme colors for the whole app or each tab, tab bar color and opacity, keyboard color, and solid or gradient profile backgrounds for you, people you pick or everyone, keeping Instagram's own profile colors by default
- Themes also cover Instagram's own settings pages
- Pick any system or Instagram icon for each tab in Edit tabs
- Story and chat buttons each get one settings page with a live preview, and can move into the story menu or the chat + menu with tap and hold working the same
- Each action button's Configure page can change that button's icon
- Custom fonts in the post and reel text tools, each surface switchable in Theme > Fonts
- Confirm before a status bar tap scrolls to the top or a double tap likes a repost
- Hide Meta AI > Create also hides Restyle in the story editor
- Instagram Plus: bigger message peek sizes, and hold the Instagram logo to pick Plus app icons

#### Feed & filters

- Content filters in General: ads, AI-labeled posts, reels and stories, and hidden words and accounts per surface, with optional per-account lists
- Engagement filters can also hide posts and reels above a like, comment, view or repost count
- Hide music, restyle, trending, suggested reels, suggested accounts, Instants or survey cards between stories, one by one
- Hide the emoji bar above the comment box
- Opening something RyukGram hides tells you why it's missing

#### Reels

- Reel date next to the author, tap for the full date
- Reels limit: always-allowed places like Messages, a custom day start, and a strict mode countdown before RyukGram settings open
- Disable scrolling reels can apply only outside the Reels tab
- Auto scroll can stop at the end of a reel instead of moving on
- Hold Controls can open the playback panel when you hold a reel
- Download every episode of a series from a profile's Series tab

#### Stories

- Hide the comments on stories, and optionally the comment button
- The story action button lists every link in a story, tracking removed, to open, copy or share
- Hold someone in story mentions to open their profile or picture, or copy their username, link, name or ID
- Hold previous or next in the story playback panel to jump to another person
- Meta glasses mode in Stories > Advanced edits story photos and videos with the glasses tools
- Stories archive and the viewer list show each viewer's poll, quiz and slider answer with the results on top, searchable
- Expired stories opened from the Gallery open the highlight they're in

#### Messages

- Keep disappearing messages after they're seen or time out, log them with their media and tag them as Disappeared
- Allow screenshots of disappearing DM photos and videos
- Auto-save photos and videos from people you pick, view-once included, into a Gallery folder per person or Photos, with optional HD
- Unsend several of your messages at once from the Delete for you selection
- Per-chat notifications: deliver quietly, hide the text or the name and text, or set a sound, from the chat + menu or the new Instagram notifications page
- Leave chat after seen returns to the inbox once you mark a chat seen
- Accurate active status lets you pick how often presence refreshes, and offline alerts use the time someone actually left
- Hold the inbox status dot to turn your activity status off for 1 hour, 8 hours or until tomorrow
- Hidden chats stay out of unread badges and DM search, hide again when you choose and can show a hidden icon, and locked chats can show a lock icon
- Hide story rings in the inbox and chat header
- Messages action button can show on normal chat photos and videos

#### Instants

- Confirm Instants capture keeps the exact photo you tapped, lets you watch a video before sending and applies without a restart
- Exclude people from manual seen, or block only the people you pick
- Move to the next Instant after marking one seen

#### Profiles & watchlist

- Profile Analyzer Growth card with a trend line and a full growth page, plus change markers on the header counts
- Deleting a wrong latest scan rolls the analyzer back to the scan before it
- Watchlist saves new notes with the song and clip time, per account or by default, and Media Watch saves new highlight items per highlight
- Watchlist and Visited profiles can be tabs and home shortcuts
- Hide your followers and following lists or yourself from other people's lists, and swap the Message button in your own lists for Following or Remove
- Follow buttons in analyzer lists, the grid feed and follow requests ask first when follow or unfollow confirm is on
- Open link from clipboard also takes usernames

#### Saving & gallery

- Save all can save tagged posts and save straight to Photos
- Download audio from feed, reels, stories and disappearing DM action menus, and Copy media copies the photo or video itself
- Image comments opened full screen get a download button, and comment menus can copy the image or GIF itself
- Lock single Gallery folders with your passcode, hidden everywhere until unlocked
- Gallery settings can show auto-saved DMs in their own folder, with other media or hidden
- Media viewer: Live Text on photos and paused videos, hold a video for 2x, and a menu with speed, save frame, AirPlay and Picture in Picture
- Hold the speed row and slide to fine-tune playback speed in 0.05× steps
- Free crop in the video editor
- Chat background editor previews bubble colors, with their own color, gradient and text color for your messages and theirs

#### Security & privacy

- Everything RyukGram saves is encrypted on the device under unreadable names and stays out of the Files app, existing data and older backups convert automatically
- Lock the stories archive, notification history and follow requests with your passcode

#### Advanced & feature flags

- Instagram files: browse Instagram's own folders, read plists and logs, and import, rename, move or share files and folders
- Storage page shows Instagram's cache next to RyukGram data, with clearing and auto-clear in one place
- Notification check shows whether this install gets full, partial or no notifications and how to fix it
- Disable accounts limit to add more accounts than Instagram allows
- Hold any switch in settings to copy a Shortcuts link that turns it on, off or toggles it
- Instagram API page shows when Instagram asked to slow down and when checks resume
- Tested feature flag presets, one switch each: new home, classic tab bar and inbox, story GIF replies, hold like to react, reels hold menu, comments header, profile reels sorting, keep music playing and more
- Every MobileConfig config and field in Instagram 455 and 456 is named, with the new ones marked

### 🛠 Fixes

#### Instagram compatibility

- Read receipts, the unlocked composer, story buttons, native DM saving, voice message downloads, sticker export, Meta AI menu hiding and keep deleted messages work on Instagram 456
- Reels downloads, expand, carousels and the multi-finger gesture work again on 455 and 456, now with the quality picker
- Reels action button, Picture in Picture, frame grab, like confirmation and tap to mute work again on 455, photo reels and account switches included
- Story playback controls, auto-advance stop, mentions, marking seen and Show quiz answer work again on 455
- Following feed, story tray filters, Stories Archive video detection and hiding feed videos work again on 455
- Home shortcut, DM inbox header buttons and the home refresh and scroll options work on Instagram's new home and inbox
- Follow requests tracking and Confirm follow work again on accounts where they stopped
- Splitting long story videos opens again on the newer story gallery
- Holding the DM inbox title reveals hidden chats when it shows "Messages"
- Compact save sheet works with Instagram's new save sheet
- Confirm Instants capture asks before every photo and video with the new shutter, and No never sends

#### Messages & stories

- Holding a message opens reactions again instead of copying its text
- View-once capture while Instagram is closed works in disappearing chats and with several accounts logged in
- Holding a locked chat no longer previews it
- Selecting messages with Delete for you works with the unlocked composer on
- Chat background colors stay on voice messages while playing and after holding
- Saving a message with several photos or videos goes through RyukGram's save menu, and native saving applies without a restart
- Unsent messages are kept and marked on all your accounts, stay out of your other accounts' chats, and the unsent tag no longer overlaps text or clips on wide media
- Deleting from the deleted messages log also removes the kept message, and the log names 1:1 chats after the other person
- Chats read locally keep the orange eye, and marking a story seen on one account no longer lets your other accounts' views through
- Stories you've seen locally move to the end of the tray
- Story viewer filters search every viewer, and Stories Archive no longer shows 0 viewers on the new story tray
- Mark all in the story seen menu moves on to the next person with Advance on mark seen
- View-once media waits while a menu or share sheet is open
- Story and DM media buttons survive folding an iPhone Duo and act on the right story when stories sit side by side
- Bypass "You can't send messages" keeps the Accept and Decline bar on requests

#### Media & downloads

- HDR gallery videos sent as Instants keep their colors, play smoothly and stop at the end
- Lossless CRF 0 encoding saves again
- Bulk HD downloads no longer crash when they finish
- Holding a profile picture to save it works again on profiles
- Favorite GIFs keep their previews
- Export works on your own cutout stickers and on GIPHY stickers in chats
- Save all shows in the profile menu without the Gallery and saves to Photos then

#### Interface & stability

- Follow status tag gets its own row under the follower counts
- Inbox header buttons no longer cover your username
- RyukGram settings as a tab keep their cards with OLED, and RyukGram screens follow the theme's light or dark choice
- Toasts no longer vanish when the menu that opened them closes
- Instagram Plus fonts show unlocked, and Plus only lists features that work without a subscription
- Reels and story speed applies on every account
- Custom fonts no longer freeze settings or crash story text
- Clearing device data no longer crashes, and cache auto-clear runs once per launch and keeps RyukGram files
- Crash reports skip restarts and app switcher quits, and MobileConfig restarts no longer trip the crash guard
- Reels limit counts every reel, feed reels count toward Feed, and profile reels no longer jump with the session limit
- Switching accounts applies that account's profile, theme, tab bar and Messages-only mode right away, and Messages-only turns on without a restart
- Locked tabs respect Lock every time and stay hidden in the app switcher, and cancelling a lock no longer leaves the app covered
- Spotify and other apps keep playing when Instagram opens
- MobileConfig string and double settings show their real type and apply
- Profile Analyzer paces scans of large accounts
- Declining Confirm follow no longer logs a request
- Hide Meta AI keeps the Drafts tab
- Slovak translation fixes, thanks to @dddaaadddooo

### ⚠️ Known issues

- Unfollow confirmation is missing on profiles in Instagram 446 and later
