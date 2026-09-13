# Rendezvous

A native iOS client for browsing and reading content from Hitomi.la.

> **Status:** Work in progress. The project is currently preparing for an initial public release.

## Features

- Browse galleries by preferred language
  - English
  - 日本語
  - 한국어
- Infinite scrolling gallery list
- Full color-coded tag list on every gallery card
- Pull to refresh
- Tap a gallery to open the reader, or touch and hold to view its details
- Search by title, tag, or exact gallery ID
  - Add color-coded tag suggestions without immediately starting a search
  - Combine multiple tags with spaces to narrow results
- Save favorite galleries and browse them from a favorites-only list
- Download galleries into the app's Documents directory
  - Read completed downloads in the app without loading images from the network
  - Monitor, cancel, retry, or delete downloads from the Downloads screen
  - Access saved files in Files > On My iPhone > Rendezvous > Downloads
- Gallery detail view
  - Copy gallery IDs to the clipboard
  - Browse thumbnails for every page
  - Color-coded tags ordered by category and name
    - Male tags in blue
    - Female tags in pink
    - Other tags in gray
- Two reader view modes
  - **Basic Slide** — reads galleries with vertical scrolling
  - **Book Reading** — displays one page at a time with Japanese and standard page directions
- Current page indicator
- Reader image caching
- Automatic retry for transient image loading failures
- Automatic recovery from stale image routing data and HTTP 404 responses
- Two reader loading modes
  - **Data Saving Mode** — loads images as needed
  - **Smooth Reading Mode** — preloads gallery images in the background
- Cellular data warning for large galleries
- Reader settings persist between app launches
- Localized UI for English, Japanese, Korean

## Screenshots

Screenshots will be added before the first release.

## Installation
(Prebuilt IPA files are currently not available.)

1. Clone this repository.
2. Open the Xcode project.
3. Select your signing team.
4. Build and run on an iPhone or iOS Simulator.

## Notes

Rendezvous retrieves gallery metadata and images from third-party services at runtime.  
Network behavior and availability may change if those services modify their endpoints or delivery logic.

## Disclaimer

Rendezvous is an independent, unofficial project and is not affiliated with, endorsed by, or operated by Hitomi.la.

This application does not host gallery content. Content is retrieved from third-party services, and users are responsible for complying with applicable laws, terms, and regulations.

## License
