# App Store Screenshots

This file specifies the screenshots in [`screenshots/`](../screenshots) and how to retake them.
App Store Connect shows them on the store listing, and App Review checks them.

## Why these screenshots

[Guideline 2.3.3](https://developer.apple.com/app-store/review/guidelines/#2.3.3) asks screenshots to show the app in use, not mainly a title, login, or splash screen.
So every screenshot shows a signed-in screen with real content, and together they cover the main features: the dashboard with poster hunting, discovering events, an event page, creating an event, and the guest list.
The dashboard comes first, as the first screenshot is the one most people see.
A separate poster hunting screenshot was dropped because its filled-in event draft looked the same as the create-event form.

## Required sizes

App Store Connect accepts portrait iPhone screenshots of 1206 × 2622 or 1179 × 2556 pixels, and iPad screenshots of 2064 × 2752 or 2048 × 2732 pixels.
It rejects other sizes, such as the 1320 × 2868 of an iPhone 17 Pro Max.
The simulators below produce the sizes in use at their native resolution, in portrait.

| Folder | Display | Simulator | Pixels |
| --- | --- | --- | --- |
| `iphone-6.3` | 6.3-inch iPhone | iPhone 17 Pro | 1206 × 2622 |
| `ipad-13` | 13-inch iPad | iPad Pro 13-inch (M5) | 2064 × 2752 |

The current iPhone set was taken on an iPhone 17 Pro Max and resampled to 1206 × 2622 with `sips -z 2622 1206`, which changes the aspect ratio by less than 0.1%.
Retake it on an iPhone 17 Pro to get its native layout.

Each folder exists once per store language: `screenshots/en-US/` and `screenshots/de-DE/`.

## Required screens

| File | Screen | URL |
| --- | --- | --- |
| `01-dashboard.png` | Home screen, including "Your next event" and poster hunting | `/dashboard` |
| `02-discover.png` | List of upcoming events | `/event` |
| `03-event.png` | An upcoming public event of the screenshot account | `/event/view/<username>/<event>` |
| `04-create-event.png` | Partly filled create-event form | `/event/create` |
| `05-guests.png` | Guest list of the event in `03` | `/event/view/<username>/<event>/guest` |

The German set uses the same paths with a `/de` prefix, such as `/de/event`, not a query parameter.

## Privacy

The screenshots are public.
They may only show the App Review demo account, its own events, and public events whose organizers would not mind.
Its credentials are in App Store Connect under App Review Information; never commit them or type them into a shell.
Currently `01`, `03`, and `05` show the demo account's public event "Board Game Night", and `05` invites `@dargmuesli`.

## Retaking them

1. Let the app open a URL at launch through a local-only change, and revert it afterwards. In `vibetype/Settings.swift`, replace the `rootUrl` line with:

   ```swift
   let rootUrl = URL(string: ProcessInfo.processInfo.environment["START_URL"] ?? "https://vibetype.app/?source=pwa")!
   ```

2. Build for the simulator:

   ```sh
   xcodebuild -project vibetype.xcodeproj -scheme vibetype -configuration Debug -sdk iphonesimulator -derivedDataPath build build
   ```

3. Create fresh simulators of the two devices above with `xcrun simctl create`. Fresh ones start in English. An existing simulator once set to German keeps sending German to the web app even after switching its language back.

4. On each booted simulator, set light appearance and a clean status bar, then install the app:

   ```sh
   xcrun simctl ui <udid> appearance light
   xcrun simctl status_bar <udid> override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
   xcrun simctl install <udid> build/Build/Products/Debug-iphonesimulator/vibetype.app
   ```

   Rebooting a simulator clears the status bar override, so set it again after a reboot.

5. Launch the app once, answer the privacy screen with "Only necessary", and sign in with the demo account. The web view keeps the session for later launches. Simulators appear in Xcode's Device Hub (`Xcode.app/Contents/Applications/DeviceHub.app`).

6. Open each screen and capture it, waiting until images have loaded:

   ```sh
   xcrun simctl terminate <udid> si.maev.twa
   SIMCTL_CHILD_START_URL='https://vibetype.app/dashboard' xcrun simctl launch <udid> si.maev.twa
   sleep 10
   xcrun simctl io <udid> screenshot --type=png screenshots/en-US/iphone-6.3/01-dashboard.png
   ```

   For the German set, use the `/de` URLs and append `-AppleLanguages "(de)" -AppleLocale de_DE` to `xcrun simctl launch`.

7. For `04`, fill in name, description, start and end, and "in person", but do not submit, or the account gets a duplicate event.

8. Look at every screenshot before keeping it: no spinner, empty list, error, toast, open keyboard, or red spell-check underline. Swiping down at the top of a page reloads it and empties forms.

9. Check the sizes, then revert the patch and clear the status bars:

   ```sh
   sips -g pixelWidth -g pixelHeight screenshots/*/*/*.png
   git checkout -- vibetype/Settings.swift
   xcrun simctl status_bar <udid> clear
   ```

## Storage

The PNGs are tracked with Git LFS through `.gitattributes`, so replacing them does not grow the Git history.
Install Git LFS before committing new ones.

## When to retake

Retake the affected screenshots when the web app's layout or wording on these screens changes visibly, when Apple changes the required display sizes, or when an event shown has passed long enough to look stale.
