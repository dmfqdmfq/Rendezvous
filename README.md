# Schwarzschild

A native iOS client for browsing and reading content from Hitomi.la.

> **Status:** Work in progress. The project is currently preparing for an initial public release.

## Features

- Browse galleries by preferred language
  - English
  - 日本語
  - 한국어
- Infinite scrolling gallery list
- Pull to refresh
- Gallery detail view
- Native vertical reader
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

Schwarzschild retrieves gallery metadata and images from third-party services at runtime.  
Network behavior and availability may change if those services modify their endpoints or delivery logic.

## Disclaimer

Schwarzschild is an independent, unofficial project and is not affiliated with, endorsed by, or operated by Hitomi.la.

This application does not host gallery content. Content is retrieved from third-party services, and users are responsible for complying with applicable laws, terms, and regulations.

## License



