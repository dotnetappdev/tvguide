# TV Guide for Apple TV

A classic Sky style TV guide for **Apple TV (tvOS 17+)**, in Sky blue and yellow, built in SwiftUI for the UK free-to-air line-up. Channels use Sky style numbers (**101 BBC One, 102 BBC Two, 103 ITV1, 104 Channel 4, 105 5**…), and you can launch straight into live TV.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ▶ TV Guide   Friday 9 October            ● Freeview · London · 12:03   7:50pm │
│                                                                              │
│ [BBC TWO] 102  BBC Two                                   ░░░ artwork ░░░░░░░ │
│ Impossible                                               ░░░░░░░░░░░░░░░░░░░ │
│ 45m  HD  S  S5 E5   Started at 1:00pm  ━━━━━━──── 23m left                   │
│ Quiz in which contestants must avoid giving impossible answers…              │
├────────────┬─────────────────────────────────────────────────────────────────┤
│ TV guide   │ On now                                                          │
│ ◉ All      │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│ ♡ Favs     │ │ BBC One  │ │ BBC Two  │ │ ITV1     │ │ Channel 4│  …           │
│ ✦ Ent.     │ └──────────┘ └──────────┘ └──────────┘ └──────────┘              │
│ 🎞 Movies   │ Today     │ 1:00pm      1:30pm      2:00pm      2:30pm           │
│ 🌍 Docs     │ 101 BBC One│ News at One ┃ Sister Boniface Mysteries │ Escape…    │
│ 📰 News     │ 102 BBC Two│ Impossible  ┃         │ Bargain Hunt     │ …        │
│ 🎈 Kids     │ 103 ITV1   │ Loose Women ┃                   │ ITV News │ …     │
└────────────┴─────────────────────────────────────────────────────────────────┘
```

## Watching live TV

- **Select** a programme that's on now (in the grid or the On now tiles) to watch the channel full screen. Select a future programme to see its info.
- **Type a channel number** Sky style – 1, 0, 1 for BBC One – from a keyboard or universal remote with number keys, or use **Channel number** in the sidebar for an on-screen keypad with the Siri Remote. It tunes after three digits or a 2 second pause.
- While watching, press **up / down** for channel up / down. A Sky style now & next banner (yellow channel number, logo, progress, what's next) appears on every change; press **select** or left/right to bring it back. **Play/Pause** pauses, **Menu** returns to the guide.

### Where the pictures come from

Apple TV has no TV tuner, so live pictures need a stream:

1. **Your own live TV source (recommended).** Under **Live TV** in the sidebar enter an M3U playlist of HLS streams, e.g. from
   - Channels DVR with an HDHomeRun Freeview tuner: `http://<server>:8089/devices/ANY/channels.m3u?format=hls`
   - Jellyfin / Plex / TVHeadend live TV, or an IPTV provider you subscribe to.

   Channels are matched to the guide by `tvg-id` (the XMLTV ids used by this app, e.g. `BBCOneLondonHD.uk`), then by channel name. Streams play in-app with AVPlayer, so they must be HLS (raw MPEG-TS from a tuner won't play).
2. **The broadcaster's app (fallback).** If a channel has no stream, the player offers **Watch in BBC iPlayer / ITVX / Channel 4 / 5 / U**. These deep links aren't officially documented by the broadcasters, so they are best effort: the app tries a live-channel link first, then just opens the app.

`TVGuide-Info.plist` allows plain `http` and local-network access so home servers work.

## Features

- **Hero info panel** – focusing anything shows its channel, title, duration, badges (HD / S / series & episode / NEW), a live progress bar with time left, the synopsis and large programme artwork.
- **"On now" preview tiles** – a rail of artwork tiles for every channel showing what's on now, a progress bar and what's on next.
- **Timeline grid (now & next and beyond)** – channels down the side, a 2 hour window of programmes sized by duration, a red **now line** and dimmed past time.
  - Press **right** on the last programme in a row (or **left** on the first) to scroll the timeline by 30 minutes; listings slide across smoothly.
  - Press **Play/Pause** to snap back to now.
  - The time header stays pinned while you scroll down through channels.
- **Sidebar** – filter by All channels, Favourites, Entertainment, Movies, Documentaries, News and Kids; enter a channel number; set up Live TV; jump to Now / Tonight / Tomorrow; choose your region; refresh.
- **Favourites & more** – press and hold any tile or programme to watch, see programme info, or add/remove the channel from favourites.
- **Programme page** – full screen artwork, synopsis and "Later on" for the channel.
- **Regional listings** – BBC One, ITV1/STV/UTV and Channel 4 follow your Freeview region (London, South East, North West, Wales, Scotland, Northern Ireland and more), including S4C, BBC Scotland and BBC ALBA where relevant.

## Listings data

Listings come from the community maintained [Freeview-EPG](https://github.com/dp247/Freeview-EPG) XMLTV feed, which covers 7 days of the Freeview EPG with programme artwork, episode numbers and channel logos. The app:

1. Downloads the feed (≈20 MB) and caches it on disk, refreshing at most every 4 hours.
2. Stream-parses it, keeping only the ~60 TV channels in the line-up (≈0.6s on a desktop CPU).
3. Falls back to the stale cache if the network is unavailable, and to generated sample listings if there is no cache at all (shown as "Sample listings · offline" in the header).

Channel numbers follow Sky's layout (1xx entertainment, 3xx movies, 5xx news, 6xx kids) but are approximate – edit `TVGuide/Models/ChannelLineup.swift` to change numbering or add/remove channels (use the XMLTV ids from the feed).

## Building

Requirements: Xcode 16 or later, tvOS 17 SDK.

1. Open `TVGuide.xcodeproj`.
2. Pick the **TVGuide** scheme and an Apple TV simulator (or your Apple TV) as the destination.
3. To run on a real device, set your team under *Signing & Capabilities*.
4. ⌘R.

The project uses a file-system synchronised group, so new files under `TVGuide/` are picked up automatically. Alternatively regenerate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.

No app icon is included yet – add an *App Icon & Top Shelf Image* set to `Assets.xcassets` before shipping to the App Store.

## Project layout

```
TVGuide/
  App/TVGuideApp.swift           App entry, URL cache for artwork
  Models/                        Channel, Programme, Region, Freeview ChannelLineup
  Services/XMLTVParser.swift     Streaming XMLTV parser (filters to wanted channels)
  Services/EPGService.swift      Download + disk cache of the Freeview feed
  Services/SampleSchedule.swift  Offline fallback listings
  Services/M3UPlaylist.swift     Live TV playlist parsing and channel matching
  Models/Broadcaster.swift       Broadcaster app deep links (fallback)
  Store/GuideStore.swift         Observable state: listings, timeline window, favourites, region
  Theme/Theme.swift              Colours, metrics, UK date/time formatting
  Views/                         Guide layout, hero panel, sidebar, tiles, grid rows, detail, live player,
                                 channel number entry/keypad, live TV and region settings
```

## Remote controls

| Where | Button | Action |
| --- | --- | --- |
| Grid | ← / → | Move between programmes; at the edges scroll the timeline by 30 minutes |
| Grid | ↑ / ↓ | Move between channels (scroll up past the first channel to reach the tiles) |
| Grid / tiles | Select | Watch the channel (on now) or open programme info (later) |
| Anywhere in the guide | Number keys | Tune Sky style, e.g. 101 |
| Grid / tiles | Press & hold | Watch, programme info, favourites |
| Live TV | ↑ / ↓ | Channel up / down |
| Live TV | Select | Show the now & next banner |
| Grid | Play/Pause | Jump back to now |
| Anywhere | Menu | Back / close |
