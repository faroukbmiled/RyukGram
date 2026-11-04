# [release] RyukGram v1.5.1

### 🆕 New features

#### Interface

- Native liquid glass tab bar on iOS 26 and later, with its options under Tab bar > Liquid glass
- Expanded photos and videos rotate to landscape while the rest of Instagram stays portrait
- Hide ads covers sponsored posts between comments
- Hide Meta AI removes the Meta AI button from the share sheet

#### Reels & stories

- Long videos get an action button, a playback panel with speed, scrubber, skip, sound and save frame, and a menu button hold option
- Hide live streams from the stories tray and the reels feed
- Split long story videos into back to back parts instead of trimming, from Photos or the Gallery
- Stories archive groups posts into one card per story, with tap-through and swipe to the next story
- Stories archive can keep thumbnails only, with viewers, counts and the full download while the link lives

#### Profiles & data

- Spoofed counts take an optional base so they show from 0, plus optional random daily growth
- Logs and archives can show data saved on your other accounts, under Profiles > Show data from
- Audio categories are shared across all your accounts

#### Instagram feature flags

- MobileConfig is now Instagram feature flags at the top of Advanced, with a shorter notice and one tap to turn it on, replacing the old experimental features menu
- Select several configs or params to turn overrides off, back on or reset them at once
- Sort by recently changed, name or number
- Record reads shows which configs Instagram reads during an action
- Every config and field in Instagram 453 is named, with the new ones marked

### 🛠 Fixes

#### Instagram compatibility

- Reel photo downloads, long press save, expanded reel photos, vanish swipe, doom-scroll limit and chat peek work again on 453
- Reel refresh confirmation and the tab button refresh option work again on 452
- Story auto-advance and playback pause work with Instagram's new story viewer
- Instants buttons show on the new Instants layout
- Withdrawn follow requests show as cancelled, and unfollowing no longer logs a request
- Custom story fonts no longer crash the font picker with Instagram's remote fonts

#### Media & downloads

- Download all saves carousel videos as videos and asks quality once, with per item picks, audio only and video only
- Save all no longer skips carousels, fills partly saved posts and saves a story once across highlights
- Save frame on reels captures the on-screen frame
- Cancelling a download stops only that one, even mid-encode, and clears its files
- Send an image as your doodle works without drawing first
- Call recordings capture the other side's video in more cases and no longer flash on quality changes
- Your camera in call recordings lands where you place it, with rounded corners and a live layout preview

#### Interface & stability

- Saved tab no longer crashes, and added tabs no longer jump to Activity or show the previous account after switching
- iPhone Duo keeps the side tab bar with hidden tabs, and holding Home opens settings
- Long post spoof counts no longer push the saves count off screen
- Restoring a backup brings back every setting, including toggles from older versions
- Backup only asks for accounts when per-account data is ticked
- Data with an undetected owner shows as Unknown in backups and Storage

### ⚠️ Known issues

- Unfollow confirmation is missing on profiles in Instagram 446 and later
