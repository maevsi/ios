# Header Artwork

This file specifies the App Store "header and search results" artwork in [`screenshots/header/`](../screenshots/header), so that a designer can rework it and hand in files that App Store Connect accepts.
The App Store shows it as a banner at the top of the product page and in place of the screenshots in search results, to people on iOS or iPadOS 27 or later.
Without it, search results show the screenshots instead.

## Files

| File | Purpose |
| --- | --- |
| `header-universal.png` | The artwork in use, uploaded as the Universal asset |
| `template.png` | Empty canvas with the art safe area outlined, to start a rework from |
| `render.swift` | Script that renders both, for small changes such as another tagline |

## Apple's requirements

From Apple's [creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/):

| Placement | Aspect ratio | Pixels | Art safe area | Formats |
| --- | --- | --- | --- | --- |
| Universal asset, used for both placements | 16:9 | 5244 × 2950 | 1402 × 962 at x 1921, y 660 | PNG |
| Product page header only | 21:9 | 3840 × 1646 | 1646 × 661 at x 1097, y 493 | PNG |
| Search results only | 3:2 | 1920 × 1280 up to 3840 × 2560 | up to 2168 × 1030 at x 836, y 765 | PNG or JPEG |

- Images must not have an alpha channel or transparency.
- Everything that must be seen goes inside the art safe area. The rest of the canvas gets cropped differently on each device and orientation, so it only carries background.
- The header and the search results placement may also take a video of 5 to 30 seconds at 30 or 60 fps, as MOV, M4V, or MP4. Videos play muted and loop.

Vibetype uses only the Universal asset.
Hand in the separate header or search results images only to replace it with one per placement.

## Vibetype's requirements

These keep reworks on brand and readable at the small size of a search result.

- **Logo:** the official logo with wordmark, [`app_logo.svg`](https://github.com/maevsi/vibetype/blob/main/src/public/assets/static/logos/app_logo.svg) from maevsi/vibetype, unmodified in shape and colour, inside the safe area.
- **Tagline:** exactly "BROWSE THE VIBE. FIND YOUR TYPE.", in capitals, inside the safe area. The same artwork serves every store language, so the tagline stays in English.
- **Type:** [Raleway](https://github.com/maevsi/vibetype/blob/main/src/public/assets/static/fonts/raleway-latin-wght-normal.woff2), the web app's typeface. No text smaller than the current tagline, which is Raleway ExtraBold at 130 px on the 5244 × 2950 canvas.
- **Colours:** the logo's colours, plus white for backgrounds.

  | Use | Hex |
  | --- | --- |
  | Text, wordmark | `#1D1D1B` |
  | Blue | `#0467F1` |
  | Red | `#FF3167` |
  | Green | `#70E884` |
  | Yellow | `#FFE504` |

- **Contrast:** the logo and tagline need a calm, light area behind them, since the logo's wordmark is dark.
- **Content:** no screenshots of the app's interface, which become unreadable at this size and already appear as screenshots. No prices, rankings, awards, or claims, which App Review rejects under [guideline 2.3](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata).

## Handing in a rework

1. Start from `template.png` or rebuild its canvas and safe area in a design tool. Use `template.png` as a top layer to check the safe area, then hide it before exporting.
2. Export a PNG of exactly 5244 × 2950 pixels in sRGB, without transparency.
3. Check the export:

   ```sh
   sips -g pixelWidth -g pixelHeight -g hasAlpha header-universal.png
   ```

   It must print `5244`, `2950`, and `hasAlpha: no`.

4. Open a pull request that replaces `screenshots/header/header-universal.png`, with Git LFS installed. Link the editable source, such as a Figma file, in the pull request. If the rework no longer comes from `render.swift`, say so in the pull request, and remove the script or mark it as outdated.

## Rendering the current artwork

`render.swift` needs the logo and the font from maevsi/vibetype.
Download them to a folder outside the repo, then render:

```sh
mkdir -p /tmp/vibetype-brand
gh api repos/maevsi/vibetype/contents/src/public/assets/static/logos/app_logo.svg --jq .content | base64 -d > /tmp/vibetype-brand/app_logo.svg
gh api repos/maevsi/vibetype/contents/src/public/assets/static/fonts/raleway-latin-wght-normal.woff2 --jq .download_url | xargs curl -sL -o /tmp/vibetype-brand/raleway.woff2
swift screenshots/header/render.swift /tmp/vibetype-brand/app_logo.svg /tmp/vibetype-brand/raleway.woff2 screenshots/header/header-universal.png
swift screenshots/header/render.swift /tmp/vibetype-brand/app_logo.svg /tmp/vibetype-brand/raleway.woff2 screenshots/header/template.png --template
```

Add `--safe-area` instead of `--template` to outline the safe area on a render while checking it.

## Uploading

In App Store Connect, open the app's product page information, choose **Header and Search Results**, then **Header**, upload `header-universal.png`, and select **Use header asset in search results**.
