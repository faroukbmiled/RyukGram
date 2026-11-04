<div align="center">

# RyukGram

**The Instagram tweak for iOS power users.**

`v1.5.1` · Instagram 453.0.0 | Instagram 410.1.0

<sub>The Instagram 410 build is for older iOS versions and trails the main build on newer features.</sub>

<p>
  <a href="https://github.com/faroukbmiled/RyukGram/releases/latest"><img src="https://img.shields.io/badge/Download-Latest%20release-7C3AED?style=for-the-badge&labelColor=1F2430" alt="Latest release" height="32"></a>
  <a href="https://t.me/ryukgram"><img src="https://img.shields.io/badge/Telegram-Channel-2AABEE?style=for-the-badge&labelColor=1F2430" alt="Telegram" height="32"></a>
  <a href="https://buymeacoffee.com/axryuk"><img src="https://img.shields.io/badge/Donate-Support%20the%20project-E5484D?style=for-the-badge&labelColor=1F2430" alt="Donate" height="32"></a>
</p>

<p>
  <a href="https://github.com/faroukbmiled/RyukGram/issues">Issues</a>
  ·
  <a href="#translating">Translate</a>
  ·
  <a href="#features">Features</a>
</p>

</div>

---

> [!NOTE]
> RyukGram is [closed source](#credits) for now and will open up again later. Builds and translations stay current here.

## Install

### Add it in one tap

<div align="center">

<a href="https://store.ryuksign.com"><img src="https://img.shields.io/badge/Add%20RyukGram-store.ryuksign.com-7C3AED?style=for-the-badge&labelColor=1F2430" alt="Add RyukGram" height="36"></a>

</div>

Open it on your phone and everything is one tap away. Add it once and updates arrive on their own.

- **Sideload.** Adds the source to **Feather** or **RyukSign**, **SideStore**, or **AltStore**. Pick the **plugins** build normally, or **no plugins** if you sign with a free Apple account, since free accounts cannot sign the bundled extensions.
- **Jailbreak.** Adds the repo to **Sileo** or **Zebra**, then installs the build that matches your setup. To paste it by hand the repo is `https://source.ryuksign.com/apt/`.

### Build your own IPA

Instagram itself cannot be bundled here, so you bring the Instagram IPA and the build slots RyukGram into it.

**With GitHub Actions, no Mac needed.** Fork this repo, open the **Actions** tab, and run **Build sideloaded IPA from Release Assets**. Give it your Instagram IPA and it hands back a patched IPA ready to sign and install. Turn on the no-plugins option if you sign with a free account.

**Or by hand** with a tool like cyan, injecting into your own Instagram IPA:
- Regular build. Inject `zxPluginsInject.dylib` into the app and its plugins. The normal one, with the bundled extensions.
- No-plugins build. Inject `NoPluginsPatch.dylib` instead. For a plugin free sideload, or a free account where extensions cannot be signed.

### Download the .deb

Prefer the file? Both builds are on the [latest release](https://github.com/faroukbmiled/RyukGram/releases/latest).

<table>
  <tr>
    <th align="left">File</th>
    <th align="left">Build</th>
  </tr>
  <tr>
    <td><code>RyukGram_x.x.x_rootless.deb</code></td>
    <td>Rootless</td>
  </tr>
  <tr>
    <td><code>RyukGram_x.x.x_rootful.deb</code></td>
    <td>Rootful</td>
  </tr>
</table>

The rootless .deb also carries the dylib and bundle the sideload builds use.

### TrollStore

Download `RyukGram_trollfools.zip` from the [latest release](https://github.com/faroukbmiled/RyukGram/releases/latest) and inject it into Instagram with TrollFools.

---

Once it is running, open the settings by holding the button at the top of your profile, or the home button in the tab bar. Screenshots are [below](#opening-settings).

## Features

### General
- Hide ads and Meta AI
- Hide the TestFlight popup and turn off app haptics
- Always mute keeps everything silent until you tap a speaker or press volume
- Copy captions, comments, and profile info, or select just part of the text
- Download, copy, or expand image and GIF comments
- Send any Giphy link as a comment GIF and pin your favorites
- Download audio from the reels audio page or any music picker
- Audio categories in every music picker: hold a song to file it, then play and pick from a row under the tabs
- Clean shared links for embeds and strip tracking, with your own param list
- Open links in an external browser or straight from the clipboard
- Tappable links, emails and phone numbers in captions, comments and bios
- Native color picker, teen app icons, and the bundled app icons
- Liquid glass controls with a force off switch
- Instagram Plus features, or just hide its upsells
- Notes tweaks: hide the tray or friends map, custom themes
- Hide suggested accounts and searches, trending, the explore grid, sensitive covers, and surveys
- Compact save sheet that skips the empty collections prompt
- Hide reels in explore
- Stat pills on search and explore, picked and reordered by you
- Anonymous live viewing and toggleable live comments
- Redact RyukGram's buttons in screenshots and recordings
- Update checker with release notes
- Safari extension that opens any Instagram page in RyukGram and blocks app prompts
- Crash logs you can search and share

### Feed
- Grid feed: your home feed as thumbnails with stats, columns, shapes, spacing, shading, rounded corners and date format of your choice
- Hold a tile to preview, like, follow, expand, share, or copy the link
- Switch back to Instagram's feed from the header or a floating button
- Hide the stories tray, suggested stories, highlights, and live streams
- View a profile picture from a story tray long press
- Hide the whole feed, or just suggested posts, accounts, reels, threads, and Facebook cards
- Cap posts in a row and filter by minimum likes, comments, views, or reposts
- Turn off video autoplay
- Hide the full screen button on feed videos
- Play feed reels in place
- Long press any media to open it full screen
- Custom date format with relative times
- Turn off background and home button refresh
- Status bar tap scrolls up only, or does nothing
- Stop the feed swipe from opening the camera
- Confirm pull to refresh, or refresh only the stories tray
- Reorder, hide, or drop the counts on post buttons

### Reels
- Custom tap controls and auto scroll that skips sponsored and photo reels
- Hold controls for pause, the options menu, or picture in picture
- Playback menu for speed, seek, next and previous, sound, and picture in picture
- Action button, playback menu and menu button hold in the long video player
- Always visible scrubber, no auto unmute, and refresh confirmation
- Expanded view without cropped sides
- Unlock password locked reels
- Reorder, hide, or drop the counts on sidebar buttons
- Hide the header, friend avatars, promo pills, the comment bar, and live streams
- Swipe left to open the author's profile
- Show the repost date
- Disable reel scrolling
- Reels limit per session or per day, with time or reel caps, chosen weekdays, reels-free days, a week chart, break nudges, and strict mode
- Limited extra time with a daily cap and optional wait
- Hide feed videos once a limit hits
- Filter reels by minimum likes, comments, views, or reposts
- Enhanced pause and play mode

### Action buttons
- Context aware menus on feed, reels, stories, DMs, and profiles
- Configurable default tap and icon browser
- Bulk download carousels and multiple stories
- Save a photo post with its music as a video
- Save a photo story as just the image
- Repost through Instagram's own flow
- Full screen viewer with zoom and swipe
- Drag overlay buttons into place on a live preview, with size and spacing controls

### Profile
- Zoom or save the profile picture, and view every picture on the account
- View highlight covers from a long press
- Action button for info, the picture, and follower stats
- Follows you back indicator in lists and on profiles
- Copy notes and reveal full counts
- Spoof your picture, username, name, bio, Threads handle, stats, badge, post metrics and story views on your device
- Clone any profile into your spoof and keep it synced
- Spoof multipliers that grow with the real count, with an optional base and random daily growth
- Hide the Threads button
- Sort and search follower and following lists
- Follow request tracker, even for requests canceled before you answer
- Confirm or decline follow requests in bulk, with a warning before asking someone who declined you

### Profile analyzer
- Follower and following scans with mutuals and non followbacks
- New and lost trackers across scans
- Change history for name, username, bio, and picture
- Inline and batch follow, unfollow, and remove
- Private log of profiles you open, with notes, filters and export
- Watchlist that checks accounts on a schedule
- Tracked changes for username, name, bio, links, picture, privacy, follow back and counts, with alerts per type
- Watchlist saves new stories, posts, reels and profile pictures to the gallery
- Per check toggles and a badge for gains and losses

### Saving
- HD downloads up to 1080p with a quality picker and preview
- Full resolution photos, or pick the size
- Audio only and raw photo options
- Save, share, or copy any sticker, animated ones included
- Save all media from any profile by count or date range, queued with a daily limit
- Download manager with live speed, filters, and bulk select
- Download history with redownload
- Duplicate check before saving the same media twice
- Auto retry for dropped downloads
- Save into a dedicated RyukGram album
- Advanced encoding for codec, bitrate, and resolution
- Consistent filenames stamped with the post date, with an optional `ryuk_` prefix
- Optional download confirmation

### Gallery
- Private in-app library for every download
- Images, video, audio, and animated GIFs
- Filter by type, source, uploader, date, favorites, and folders
- Sort by date, name, or size
- Group by user into sections or folders, from 2 to 5 columns
- Posts and stories stay one swipeable album, which you can group or split
- Import your own photos, videos and files
- Pick from it inside Instagram to send or post several at once
- Repost any photo, video or GIF as a story, post or reel
- Edit photos, videos, audio and GIFs, saved as new or over the original
- Info page with source details, camera and codec info, and location removal
- Upgrade saved media to HD
- Save a folder or the whole view to Photos
- Deleted filter for saved posts and stories removed from Instagram

### Stories and messages
- Keep deleted messages, including your own unsends, marked how you like
- Searchable log of every unsent message, with a jump to where it sat
- Catch view-once media that arrives while Instagram is closed
- Log view-once media when you open it
- Activity notifications for reads, online, offline, and typing, per person
- Activity log as a filterable timeline
- Accurate active status
- Story playback menu for speed, seek, next and previous, sound, and picture in picture
- Your own fonts in the story text tool
- Manual and automatic mark as seen
- Hold the eye button to mark a whole story reel seen, or up to where you are
- Mark chats seen on your device only
- Seen stories hide or tint the eye button for 48 hours
- Send audio as a file or voice note, with a trim editor
- Send an image as your doodle in Draw
- Download voice messages
- Force the missing sound toggle in the DM camera
- Turn off typing status, the vanish swipe, and view once limits
- Pick the score you send in the DM emoji game
- Hide shared reels in chats
- Toggle your activity status from the DMs inbox
- Custom chat backgrounds from an image, video, or GIF
- Filter, sort, search, and pin story viewers, with their reactions
- Archive your own stories with their viewers, plus story stats
- View story mentions and reveal poll and quiz results
- Bypass Reveal stickers and pick custom sticker colors
- Cutout stickers from the gallery
- Story backgrounds in any color or gradient
- Long videos post to stories as back to back parts, not trimmed
- Download disappearing DM media in full quality
- Hide the views toggle and keep views blocked
- Send Instants from your album, with crop and trim
- Auto close the Instants viewer
- Toggle the Instants switch confirmation from the viewer
- Keep Instants unseen until you mark them seen
- Record voice and video calls, browsed per person
- Save, share, or delete recordings in bulk, or share them as audio only

### Interface
- Custom notification sounds for DMs and other alerts
- Hide Instagram's in-app banners
- Notification pill you can place anywhere
- Mirror notifications to the iOS notification center
- Reorder and hide tab bar icons on a live preview
- Native iOS liquid glass tab bar on iOS 26 with 5 tabs or fewer
- Add RyukGram screens, Saved and Activity as tabs, and pick the launch tab
- Hold any tab to open a RyukGram screen
- Messages-only mode on a schedule, for a set time, or from Shortcuts links
- Shortcuts links to switch Messages-only and Reels limit from iOS automations, or from a file without opening Instagram
- Force Instagram into any supported language
- Home shortcut button with new item badges, also shown on added tabs
- Notification history with filters and search
- Bring back the old Instagram logo
- Instagram feature flags browser to read, change, export and import Instagram's internal MobileConfig settings
- Every MobileConfig config named, with notes, search, and new ones marked per update
- Record which configs Instagram reads during any action

### Confirm actions
- Optional confirmations for likes, follows, reposts, calls, comments, and more
- Confirm DM reactions

### Fake location
- Override your location with a map picker and saved presets

### Theme
- Off, light, dark, or OLED, applied to Instagram only
- OLED chat theme and matching keyboard
- Custom fonts for Instagram, RyukGram, or both
- Import your own fonts, or download from thousands online
- Custom emoji fonts
- Manage installed fonts in bulk

### Security and privacy
- Mask the device identifiers Instagram reads
- Passcode and biometric lock for settings, chats, logs, recordings, and the app
- Hidden chats with per account lists, optionally kept out of the share sheet
- App switcher shroud and hidden previews for locked chats

### Backup and profiles
- Export settings and feature data as JSON or an encrypted bundle
- Restore with replace or merge, scoped to the accounts you pick or into a new profile
- Save your setup as a named profile and switch in a tap
- Name, color, duplicate, or share profiles as files
- Tie a profile to Instagram accounts so it switches with them
- Reset a profile or turn everything off in it
- See and clear what RyukGram keeps on your device

### Localization
- English, Spanish, French, Russian, Korean, Japanese, Arabic, Vietnamese, Chinese, Portuguese, Turkish, Indonesian, and Slovak
- In app language picker

### Optimization
- Clear the Instagram cache on demand or on a timer
- Instagram API controls to reuse replies, pace requests, and cap daily actions and scans

## Translating

Want RyukGram in your language? Export the strings from **Settings, Debug, Localization**, translate the right side of each `"key" = "value";` line, and open a pull request with your file at `src/Localization/Resources/<code>.lproj/Localizable.strings`. Keep the format specifiers like `%@` and `%lu` exactly as they are. Missing lines fall back to English, so partial work is welcome. Anything you contribute is licensed to the project under the same terms as RyukGram.

## Opening settings

|                                             |                                             |
|:-------------------------------------------:|:-------------------------------------------:|
| <img src="https://i.imgur.com/OnjLpZK.png"> | <img src="https://i.imgur.com/pHIuYTm.jpeg"> |

## Credits

RyukGram got its start from [SCInsta](https://github.com/SoCuul/SCInsta) by [@SoCuul](https://github.com/SoCuul), and I'm grateful for the foundation it gave the project. That code has since been fully rewritten and none of it remains, so RyukGram is its own separate codebase. It went closed source because earlier releases were being lifted and resold as paid tweaks, which is something I can't keep feeding, and I know some of you valued it staying open. Thanks to @SoCuul and the wider iOS tweak scene for paving the way.

- [**@SoCuul**](https://github.com/SoCuul) for SCInsta, the spark for this project
- [**@BandarHL**](https://github.com/BandarHL) for BHInstagram
- [**@VAXMG**](https://t.me/ciesIPAs) for OLED theme inspiration
- [**@euoradan**](https://t.me/euoradan) for experiment flag research
- [**@n3d1117**](https://github.com/n3d1117) for the Following feed
- [**BillyCurtis**](https://github.com/BillyCurtis/OpenInstagramSafariExtension) for the Safari extension base
- [**@asdfzxcvbn**](https://github.com/asdfzxcvbn) for ipapatch and zxPluginsInject
- Furamako, [@ZomkaDEV](https://github.com/ZomkaDEV), [@ch1tmdgus](https://github.com/ch1tmdgus), [@hooray804](https://github.com/hooray804), [@bruuhim](https://github.com/bruuhim), [@jaydenjcpy](https://github.com/jaydenjcpy), [@brunorainha](https://github.com/brunorainha), [@yesnt10](https://github.com/yesnt10), [@tranbinh02](https://github.com/tranbinh02), [@yannouuuu](https://github.com/yannouuuu), [@willybilly981](https://github.com/willybilly981), [@diemasmahendra](https://github.com/diemasmahendra), and [@dddaaadddooo](https://github.com/dddaaadddooo) for translations

## Support

If RyukGram earns a spot on your phone, you can keep it going here.

<div align="center">

<a href="https://buymeacoffee.com/axryuk"><img src="https://img.shields.io/badge/Donate-Support%20the%20project-E5484D?style=for-the-badge&labelColor=1F2430" alt="Donate" height="32"></a>
<a href="https://github.com/faroukbmiled/RyukGram"><img src="https://img.shields.io/badge/Star-the%20repo-6B7280?style=for-the-badge&labelColor=1F2430" alt="Star the repo" height="32"></a>

</div>
