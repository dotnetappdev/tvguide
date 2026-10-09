# TV Guide for Apple TV

A modern, Sky Q inspired electronic programme guide for **Apple TV (tvOS 17+)**, built in SwiftUI for the UK **Freeview** line-up.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ▶ TV Guide   Friday 9 October            ● Freeview · London · 12:03   7:50pm │
│                                                                              │
│ [BBC TWO] 2  BBC Two                                     ░░░ artwork ░░░░░░░ │
│ Impossible                                               ░░░░░░░░░░░░░░░░░░░ │
│ 45m  HD  S  S5 E5   Started at 1:00pm  ━━━━━━──── 23m left                   │
│ Quiz in which contestants must avoid giving impossible answers…              │
├────────────┬─────────────────────────────────────────────────────────────────┤
│ TV guide   │ On now                                                          │
│ ◉ All      │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│ ♡ Favs     │ │ BBC One  │ │ BBC Two  │ │ ITV1     │ │ Channel 4│  …           │
│ ✦ Ent.     │ └──────────┘ └──────────┘ └──────────┘ └──────────┘              │
│ 🎞 Movies   │ Today     │ 1:00pm      1:30pm      2:00pm      2:30pm           │
│ 🌍 Docs     │ 1 BBC One │ News at One ┃ Sister Boniface Mysteries │ Escape…    │
│ 📰 News     │ 2 BBC Two │ Impossible  ┃         │ Bargain Hunt     │ …        │
│ 🎈 Kids     │ 3 ITV1    │ Loose Women ┃                   │ ITV News │ …     │
└────────────┴─────────────────────────────────────────────────────────────────┘
```

## Features

- **Hero info panel** – focusing anything shows its channel, title, duration, badges (HD / S / series & episode / NEW), a live progress bar with time left, the synopsis and large programme artwork.
- **"On now" preview tiles** – a rail of artwork tiles for every channel showing what's on now, a progress bar and what's on next.
- **Timeline grid (now & next and beyond)** – channels down the side, a 2 hour window of programmes sized by duration, a red **now line** and dimmed past time.
  - Press **right** on the last programme in a row (or **left** on the first) to scroll the timeline by 30 minutes; listings slide across smoothly.
  - Press **Play/Pause** to snap back to now.
  - The time header stays pinned while you scroll down through channels.
- **Sidebar** – filter by All channels, Favourites, Entertainment, Movies, Documentaries, News and Kids; jump to Now / Tonight / Tomorrow; choose your region; refresh.
- **Favourites** – press and hold any tile or programme to add/remove the channel.
- **Programme page** – full screen artwork, synopsis and "Later on" for the channel.
- **Regional listings** – BBC One, ITV1/STV/UTV and Channel 4 follow your Freeview region (London, South East, North West, Wales, Scotland, Northern Ireland and more), including S4C, BBC Scotland and BBC ALBA where relevant.

## Listings data

Listings come from the community maintained [Freeview-EPG](https://github.com/dp247/Freeview-EPG) XMLTV feed, which covers 7 days of the Freeview EPG with programme artwork, episode numbers and channel logos. The app:

1. Downloads the feed (≈20 MB) and caches it on disk, refreshing at most every 4 hours.
2. Stream-parses it, keeping only the ~60 TV channels in the line-up (≈0.6s on a desktop CPU).
3. Falls back to the stale cache if the network is unavailable, and to generated sample listings if there is no cache at all (shown as "Sample listings · offline" in the header).

Channel numbers follow the England Freeview plan and are approximate – edit `TVGuide/Models/ChannelLineup.swift` to change numbering or add/remove channels (use the XMLTV ids from the feed).

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
  Store/GuideStore.swift         Observable state: listings, timeline window, favourites, region
  Theme/Theme.swift              Colours, metrics, UK date/time formatting
  Views/                         Root layout, hero panel, sidebar, tiles, grid rows, detail, region picker
```

## Remote controls

| Where | Button | Action |
| --- | --- | --- |
| Grid | ← / → | Move between programmes; at the edges scroll the timeline by 30 minutes |
| Grid | ↑ / ↓ | Move between channels (scroll up past the first channel to reach the tiles) |
| Grid / tiles | Select | Open the programme page |
| Grid / tiles | Press & hold | Add or remove the channel from favourites |
| Grid | Play/Pause | Jump back to now |
| Anywhere | Menu | Back / close |
