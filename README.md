<div align="center">

# RyukGram

**The Instagram tweak for iOS power users.**

`v1.3.3` · Instagram 439.0.0 | Instagram 410.1.0

<sub>The Instagram 410 build is for older devices and trails the main build on newer features.</sub>

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
- Hide ads, Meta AI, and like, comment and share counts
- Hide the TestFlight popup and turn off app haptics
- Copy captions, comment text, and profile info
- Download, copy, or expand image and GIF comments
- Send any Giphy link as a comment GIF, and pin the ones you favorite
- Download audio from the reels audio page
- Clean shared links for embeds and strip their tracking
- Open links in an external browser or straight from the clipboard
- Native color picker and teen app icons
- Liquid glass controls, with a force off switch and tab bar behavior
- Instagram Plus turns on Instagram's own paid features
- Notes tweaks: hide the tray, hide the friends map, custom themes
- Drop suggestions, trending, the explore grid, sensitive covers, and surveys
- Stat pills on search and explore, with a page to pick and reorder them
- Anonymous live viewing and toggleable live comments
- Redact RyukGram's own buttons in screenshots and recordings

### Feed
- Grid feed turns your home feed into thumbnails, each with its stats and author
- Pick which stats show and their order, tile shape, columns by pinch, and the date format
- Hold a tile to preview it, or to like, follow, expand, share, or copy the link
- Switch back to Instagram's feed from the header heart or a floating button you place
- Hide the stories tray, suggested stories, and highlights
- View a profile picture from a story tray long press
- Hide the whole feed, or just suggested posts, accounts, reels, and threads
- Turn off video autoplay
- Long press any media to open it full screen, muted if you want
- Custom date format with your own template and relative times
- Turn off background and home button refresh
- Confirm before a pull to refresh, or refresh only the stories tray
- Hide the feed repost button

### Reels
- Custom tap controls and an auto scroll mode
- Playback menu for speed, seek, and auto scroll
- Always visible scrubber, no auto unmute, and refresh confirmation
- Unlock password locked reels
- Hide the header, repost button, friend avatars, and promo pills
- Swipe left to open the author's profile
- Show the repost date
- Disable scrolling and cap how many reels you can watch in a row
- Filter the reels feed by minimum likes, comments, views, or reposts
- Enhanced pause and play mode

### Action buttons
- Context aware menus on feed, reels, stories, DMs, and profiles
- Configurable default tap, and a searchable browser of Instagram and system icons
- Carousel and multi story bulk download
- Save a photo post with its music as a video
- Save a photo story as just the image
- Repost through Instagram's own flow
- Full screen viewer with zoom and swipe
- Drag to arrange your overlay buttons on a live preview

### Profile
- Zoom or save the profile picture
- View highlight covers from a long press
- Action button for info, the picture, and follower stats
- Follow indicator that shows who follows you back
- Copy notes, fake your stats, and reveal full counts
- Sort and search follower and following lists by mutuals, verified, and more
- Follow request tracker that logs every request, even ones cancelled before you answer

### Profile analyzer
- Follower and following scans, with mutuals and non followbacks
- New and lost trackers across scans
- Change history for name, username, bio, and picture
- Inline and batch follow, unfollow, and remove
- A log of every profile you open, with filters
- Per check toggles, with a badge for gains and losses since your last look

### Saving
- HD downloads up to 1080p, with a quality picker and preview
- Audio only and raw photo options
- Download manager with live speed, filters, swipe actions, and bulk select
- Download history that survives a restart, with redownload and a keep window
- Auto retry for downloads that drop offline
- Save into a dedicated RyukGram album
- Advanced encoding panel for codec, bitrate, resolution, and more
- Clean filenames on every save
- Optional download confirmation

### Gallery
- A private in app library that every download can mirror into
- Images, video, audio, and animated GIFs
- Filter by type, source, uploader, date, and favorites, with folders
- Sort by date, name, or size, with images, videos, or favorites first
- Group by user into sections or folders, from 2 to 5 columns
- Long press a user section to select all their media
- In app preview carousel
- Pull audio and GIFs straight from the gallery
- Import your own photos, videos and files into the gallery
- Grid tiles show a date chip, long press an item for its date, source and size

### Stories and messages
- Keep deleted messages, including your own unsends
- A full quality log of every unsent message, grouped by chat and searchable
- Activity notifications for reads, online, offline, and typing, set per person
- An activity log that keeps it all as a timeline, filterable and swipe to delete
- Accurate active status so the green dot turns off the moment someone leaves
- Manual and automatic mark as seen
- Mark chats seen on your device only, the eye button stays orange until you really send it
- Stories you already marked seen hide or tint the eye button for 48 hours
- Send audio as a file or a voice note, with a trim editor
- Send an image as your doodle in Draw, with a crop, resize, and background remover
- Download voice messages
- Turn off typing status, the vanish swipe, and view once limits
- Toggle your activity status from a dot in the DMs inbox
- Custom chat backgrounds from an image, video, or GIF, with a built in editor
- Filter, sort, search, and pin story viewers, and see who reacted with what
- Archive your own stories before they expire, viewer list included, per account
- View story mentions and reveal poll and quiz results
- Bypass Reveal stickers and pick custom sticker colors
- Download disappearing DM media in full quality
- Send Instants from your album, with crop and trim editors
- Auto close the Instants viewer once you have seen them all
- Toggle the Instants switch confirmation from a button in the viewer
- Record voice and video calls into an adaptive grid, browsed per person

### Interface
- A universal notification pill you can place anywhere on screen
- Mirror toasts to the iOS notification centre, in the background or while the app is open
- Reorder and hide tab bar icons on a live tab bar preview
- Messages only mode, with a daily schedule and inbox header shortcuts
- Force Instagram into any supported language
- Home shortcut button with new item badges
- Experimental flags

### Confirm actions
- Optional confirmations for likes, follows, reposts, calls, comments, and more

### Fake location
- Override your location across the app, with a map picker and saved presets

### Theme
- Off, light, dark, or OLED, applied to Instagram only
- OLED chat theme and a matching keyboard theme

### Security and privacy
- Mask the device identifiers Instagram reads, from settings or the login screen
- Passcode and biometric lock for settings, chats, logs, recordings, and the app itself
- Hidden chats and per account lists
- App switcher shroud and hidden previews for locked chats

### Backup and restore
- Export your settings and feature data as JSON or an encrypted bundle
- Restore with replace or merge
- Scope any export, import, or reset to the accounts you pick
- See what RyukGram keeps on your device, by section and account, and clear it

### Localization
- English, Spanish, French, Russian, Korean, Japanese, Arabic, Vietnamese, Chinese, Portuguese, Turkish, and Indonesian
- In app language picker, with English as the fallback

### Optimization
- Clear the Instagram cache on demand or on a timer
- Smoother feed scrolling

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
- Furamako, [@ZomkaDEV](https://github.com/ZomkaDEV), [@ch1tmdgus](https://github.com/ch1tmdgus), [@bruuhim](https://github.com/bruuhim), [@jaydenjcpy](https://github.com/jaydenjcpy), [@brunorainha](https://github.com/brunorainha), [@yesnt10](https://github.com/yesnt10), [@tranbinh02](https://github.com/tranbinh02), [@yannouuuu](https://github.com/yannouuuu), [@willybilly981](https://github.com/willybilly981), and [@secdie](https://github.com/secdie) for translations

## Support

If RyukGram earns a spot on your phone, you can keep it going here.

<div align="center">

<a href="https://buymeacoffee.com/axryuk"><img src="https://img.shields.io/badge/Donate-Support%20the%20project-E5484D?style=for-the-badge&labelColor=1F2430" alt="Donate" height="32"></a>
<a href="https://github.com/faroukbmiled/RyukGram"><img src="https://img.shields.io/badge/Star-the%20repo-6B7280?style=for-the-badge&labelColor=1F2430" alt="Star the repo" height="32"></a>

</div>
