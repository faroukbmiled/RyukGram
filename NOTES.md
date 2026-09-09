[release] RyukGram v1.4.0

Updated for Instagram 446.0.0.

### ✨ Highlights
- **Setting profiles.** Keep several complete setups under names and switch between them in a tap. Give each one a color and icon, duplicate it, share it as a file, or tie it to an Instagram account so it follows your quick switch
- **MobileConfig browser.** Read and change Instagram's own internal settings from inside the app, with search, copiable details, and export or import of everything you changed
- **Story stats.** Overview numbers over your archive, a views-per-story chart, and a searchable audience list you can filter, sort and pin. Tap anyone to see every story of yours they watched and how they reacted
- **Custom fonts.** Import your own .ttf or .otf files or download from thousands online, then use them across Instagram, RyukGram, or the story text tool
- **Full-resolution photos.** Photos download at their original upload size, often far larger than the copy Instagram hands the app, with a picker showing dimensions, format and file size per option
- **Post and Reel buttons.** Reorder Instagram's own like, comment, share, repost and save buttons, hide any of them, or drop a count without hiding its button
- **View-once media while closed.** Catch disappearing DM media that arrives while Instagram is fully shut, and keep it in the log when it gets unsent
- **Update checker.** RyukGram tells you when a newer release is out, shows what changed, and keeps every past release on its own page under About

### 🆕 New features

#### Setting profiles
- Keep several complete setups under names and switch between them in a tap
- Profiles carry a name, color and icon, and can be duplicated, exported or shared as a file
- Link a profile to Instagram accounts and it switches with the account, with an unlinked profile covering the rest
- Reset a profile to defaults or turn everything off inside it, with a count of what is on and what differs
- Importing a backup can send its settings to a new profile instead of the ones you are using
- Backup & Restore is now Backup & Profiles, with a profile shortcut on the settings home page

#### Fonts and theme
- Import your own .ttf or .otf fonts, or download from thousands online
- Use custom fonts for Instagram, RyukGram, or both, set under Theme
- Your imported and device fonts show up in the story text tool next to the built-in ones
- Manage fonts in bulk from either font picker, with multi-select and a delete confirmation

#### Messages
- Catch view-once media that arrives while Instagram is fully closed and keep it in the log when unsent, off by default, with size and age cleanup
- Logging view-once media you open is now its own switch in the deleted messages log, off by default
- Deleted messages log entries can open the chat and jump to where the message was
- Mark kept unsent messages with a tag, a faded bubble, a tinted bubble or any mix, with your own tag text, position, size and colors
- Confirm before a reaction sends in a chat, catching only the accidental double-tap or every reaction you send
- Hide reels in chats so they never show or open in a thread
- Messages-only mode switches in place with no restart, whether you flip it yourself or the schedule does
- The messages-only schedule can ask first and switch only when you confirm

#### Stories
- Story stats for the archive: overview numbers, a views-per-story chart, and a searchable audience list with filters, sorting and pinned viewers on top
- Story stats compares the last 7 or 30 days against the stretch before it
- Tap someone in the audience list to see every story of yours they watched and what they reacted with
- Refresh names and photos from the story stats screen and any story viewers list
- Playback controls for stories with speed, seek and pause, held from the ⋯ or speaker button or opened from the story menu
- Hold the story eye button to mark a whole reel as seen, or only the stories up to where you are
- Disappearing media has its own settings page, and the mark-as-viewed button only shows when view receipts are blocked
- A slider in the layout editor sets the spacing between story and disappearing media overlay buttons
- Buttons placed next to each other close the gap when one of them is hidden, with a switch to turn it off

#### Feed and reels
- New Post buttons and Reel buttons pages to reorder Instagram's own like, comment, share, repost and save buttons, hide any of them, or drop a count without hiding its button
- Hide metrics and the two hide repost switches moved into those pages, per button instead of all at once, and your old settings carry over
- Tap a reel in the feed to play it in place instead of opening the Reels player, or play first and open on a second tap
- Hold controls for reels: force hold-to-pause, force the options menu, or the options menu with picture in picture
- The reels playback menu gains a pause control
- Expanded view shows the whole reel instead of cropping the sides
- Bring back the old Instagram logo in the feed header
- Status bar tap on the feed can scroll up without refreshing, or be turned off
- Stop the right swipe on the feed from opening the camera
- The doom-scrolling limit can cap the grids on audio, effect, template and remix pages too

#### Profile
- Fake profile options moved to their own page under Profile, with the username, name, counts and badge together
- Fake your own username and display name, shown only on your device
- Follow indicator in follower and following lists, styled separately from the profile one
- Hide the Threads button in the profile header
- Long press a tracked follow request to open the profile, view the picture, filter to that user, copy the username or delete the entry

#### Downloads and gallery
- Photos download at their full upload size, often much larger than the copy Instagram hands the app
- Pick the size a photo downloads at, with the dimensions, format and file size on every option
- Duplicate check asks before you save the same media twice, and can remove the old gallery copy first
- A post or story downloaded to the gallery stays one item you swipe through, with a switch in Gallery settings
- Group any gallery files into an album, or split one back apart, from multi-select
- Saved files share one naming scheme everywhere, stamped with the date the post went up instead of the moment you downloaded it
- Optional ryuk_ prefix on saved file names, under Media saving
- Hold a song in any music picker to download its audio

#### Calls
- Call recordings are tagged auto or manual in the list
- Select recordings to save them to the gallery, share them, share video calls as audio only, or delete them together

#### Interface and general
- Always mute starts feed, reels, stories and DMs silent until you tap a speaker or press volume
- Copied text can open in a sheet first so you can edit it or copy only the part you selected
- Hold any tab in the bottom bar to open a RyukGram screen, picked per tab under Interface, Tab bar, Tab shortcuts, replacing the separate home, search and DM hold toggles
- New MobileConfig browser to read and change Instagram's own internal settings, with search inside a config, copiable details and a home shortcut entry
- MobileConfig changes can be exported and imported from the browser menu
- Auto-clear cache can run on every launch
- Indonesian translation added

#### Updates
- RyukGram tells you when a newer release is out, shows what changed in it, and links straight to the Telegram channel
- New Updates page under About with the update status, what is new in your build, every past release, and switches for the automatic checks
- Tapping the RyukGram name or version on the settings links sheet opens the Updates page

#### Privacy
- Machine ID masking, pinned like the rest of the identifiers, with copy and manual entry
- Mask everything and relaunch rolls every identifier, blocks Apple attestation and clears saved logins in one tap, from Settings or the login screen button

#### Backup
- Backup, restore and storage now list MobileConfig changes and the duplicate download list as their own items
- Restored MobileConfig changes wait until you turn the browser on

### 🛠 Fixes

#### Instagram 443 to 446
- Marking a story seen works again on Instagram 446
- Story text color picker applies your color again on Instagram 446
- Note actions row shows again when you hold a note on Instagram 446
- The icon browser drops the color pet icons Instagram 446 removed, and a button whose icon is gone shows a marker instead of nothing
- Online status updates work again on Instagram 445
- Story mentions button refreshes again when a story opens on Instagram 445
- Story viewer list header buttons are back on Instagram 445, and the reload button works for the first time
- Call buttons hide again on Instagram 444
- Chat backgrounds keep showing after a theme change on Instagram 444
- The old feed logo works again on Instagram 444
- Follow confirmation works again on Instagram 443
- Hiding the reels header works again on Instagram 443
- The icon browser picks up the icons added in Instagram 441
- Instagram Plus story fonts unlock again, and the upgrade prompt stays away
- Instagram Plus story peek now works on DM inbox avatars, not only the stories tray
- Message peek shows the chat, drops the upgrade row from the menu, and opens the chat when you tap it

#### Messages
- Kept unsent messages no longer disappear when a chat reloads its older history, survive a restart, and now cover older messages you never opened
- Unsent messages recovered from an older part of a chat now show who sent them and get logged with their content
- The unsent notification names the chat instead of saying a message was unsent, when the message itself cannot be recovered
- Deleted messages log shows when an old message was originally sent, so it cannot be mistaken for a new one
- A chat no longer shows as read on your other account after a quick switch
- Chats marked seen locally now drop the unread bold on accounts where nothing happened before
- Bubble colors stay on the side you picked instead of leaking onto your own messages
- Gradient bubble colors no longer vanish when you scroll a chat and come back
- Moving between a chat and a reel no longer stacks a second tab bar under the first
- Hiding tabs no longer leaves the tab bar over a reel opened from a chat, or covering the message box on the way back
- Turning on the messages-only schedule asks to restart right away instead of waiting for the window to start
- Your icon order and hidden tabs survive the messages-only switch instead of all coming back

#### Stories and reels
- Opening an archived story no longer wipes its view, like and reaction counts, and counts already flattened are rebuilt from the saved viewers
- Archived story viewers whose profile picture had stopped loading show up again
- The stories archive stops re-fetching viewers for stories that were deleted on Instagram
- The story viewers "Default list" option now shows translated in every language
- Story date format now applies on accounts where Instagram uses a different timestamp style
- Reels no longer crash when scrolling away with the playback toggle on
- Rewinding a reel past its start now jumps to the beginning instead of doing nothing
- Tapping a photo in a reel carousel now mutes it as intended
- Instants no longer crash on a video they cannot read, and say so instead
- The in-call record button now hides with Instagram's own call controls, so tapping to bring them back cannot start a recording
- Calls no longer keep recording into the next call when auto-record is off

#### Downloads and files
- Downloading a video opened from search now saves the video with every quality option, instead of the cover photo
- Downloading a whole post or story keeps its items in the order they were posted
- File names no longer pick up a second extension or timestamp when the same media is saved again
- Sharing from the gallery keeps the name you see in the list instead of a raw id
- Sharing from the expanded view names the file after the account and post date instead of a raw id
- Saved profile pictures keep the quality you see in the preview
- Long pressing an avatar outside a profile page opens and saves it in HD too
- Trimming an HDR video exports instead of failing

#### Feed, profile and interface
- Instagram no longer launches into a tab you hid
- Tab bar buttons now open the tab they show when some tabs are hidden
- The explore grid no longer flashes into view when the explore page opens with it hidden
- The profile action button no longer overlaps the username in the profile top bar
- Fake verified badge stays put instead of vanishing on refresh
- The copy icon is back in the action button menus, Instagram had dropped the artwork it used
- The favorite option on comment GIFs shows its icon properly again
- Color pickers open as a smaller sheet that leaves the page behind it visible
- Confirmation popups no longer let the screen rotate where Instagram itself stays locked
- Long notification text now wraps and grows the pill instead of being cut off, with a limit and an ellipsis
- Link tracking removal strips Instagram's new igsi parameter and works on links using a custom domain
- Shared links now have the same tracking parameters removed as links opened in the browser

#### Privacy and identifiers
- Masked device identifiers now stick: they are written even when Instagram never stored one, re-applied on every launch, and Instagram can no longer swap them back mid-session
- Reverting to your real device ID no longer restores a masked value over it

#### Cache, backup and settings
- Auto-clear cache no longer skips a whole period when a clear fails or gets cut short, it retries until one goes through
- Auto-clear no longer stalls after a clock change or a restored backup
- Clearing the cache by hand no longer pushes the next auto-clear back
- Export and import no longer crash Instagram while scanning what is on the device
- Importing only asks for a restart when what you imported actually needs one
- Settings carried over from an old install no longer come back with the wrong value
- Data saved by older versions no longer crashes the screen that reads it

#### Install, updates and translations
- Changing the app icon now works when Instagram is installed through SideStore or AltStore
- App icon changes that fail now say why instead of showing a bare error
- Installing over the old pre-rename package removes it instead of running both
- The build-from-release workflow names the IPA after the Instagram version you supplied, not the one in the release
- About keeps showing the available version until you update, so dismissing the popup does not lose it
- What's new no longer shows an older release's notes when you are on a build that has not been released yet
- Release notes render properly now, so sub-headings, nested bullets and inline code no longer come through as raw text
- A broken translation falls back to English instead of crashing the screen it is on
- Korean translation reworked to read more naturally
- The Snapshots screen no longer crashes in Japanese, Turkish and Chinese

### ⚠️ Known issues
- Reopening the story text tool highlights your last custom font but starts typing in the default one until you tap it again
- Unfollow confirmation does not appear on profiles on Instagram 446
