# Are.na Screensaver

A MacOS screensaver that displays images from any [Are.na](https://www.are.na/) channel in an infinite grid.

## Requirements

- macOS 12.0 or later
- Xcode Command Line Tools (`xcode-select --install`)

## How to use
1. Download this repository
2. Configure (see above)
3. Execute the build command: `bash build.sh`



## Configuration

Create a file named `channel.yaml` and specify your Are.na channel:

```yaml
channelURL: your-channel-slug
authorizationToken: your-token-here  # Optional, required for private channels
```

> The `channelURL` is the slug from your Are.na channel URL. For example, if your channel URL is `https://www.are.na/username/my-cool-channel`, the slug is `my-cool-channel`.

### Private Channels

To use a private channel, you'll need an Are.na API token:
1. Go to [Are.na Developer Settings](https://dev.are.na/)
2. Generate a personal access token
3. Add it to `channel.yaml` as `authorizationToken`

## Building

Run the build script:

```bash
bash build.sh
```

This will:
1. Fetch all images from the specified Are.na channel
2. Download them to `build/images/`
3. Compile the Swift screensaver
4. Create `build/ArenaChannel.saver`

## Installation

After building:

- **Double-click** `build/ArenaChannel.saver` in Finder, or
- **Copy** to `~/Library/Screen Savers/` for current user, or
- **Copy** to `/Library/Screen Savers/` for all users

## Settings
Image order, number of columns, and scrolling speed can be adjusted via the screensaver `Options...` button on the Preferences app.

> [!WARNING]
> There's a bug on Mac OS where the screensavers processes don't stop but keep running forever. This means the screensaver options do not update when changing them.
The solution is to open Activity Monitor and force quit any process related to `legacyScreenSaver`.

## License

Olivier Estévez © 2026. All rights reserved.
