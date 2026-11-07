# Verify sharing the check in code on iOS

Use this prompt to start an agent on a Mac with Xcode to prove that https://github.com/maevsi/vibetype/issues/2481 is fixed in the iOS app.
The agent must report evidence, not opinions: every claim in the report needs a screenshot, a file, or command output behind it.

## Background

The iOS app wraps vibetype in a `WKWebView`, where `window.print` does nothing.
The guest page `/guest/view/<guest id>` has a "Show check in code" button for accepted invitations, which opens a modal with a QR code.
Inside the iOS app, that modal must hide "Print" and show "Share" instead.
"Share" opens the system share sheet with a PNG of the QR code, which offers "Print" and "Save Image".
"Save Image" requires `NSPhotoLibraryAddUsageDescription` in `vibetype/Info.plist`, without which iOS terminates the app.

## Inputs

Ask the human for whichever of these is missing before starting:

- `GUEST_URL`: the full URL of a guest page whose invitation the agent may accept, e.g. `https://vibetype.app/guest/view/<uuid>`
- `REF`: the maevsi/ios branch or commit to build, which must contain `NSPhotoLibraryAddUsageDescription`

The app loads `rootUrl` from `vibetype/Settings.swift`, which is `https://vibetype.app`, so the vibetype fix must already be deployed there.
If the modal still shows "Print" and no "Share" inside the app, stop and report that the deployment lacks the fix.

## Setup

1. Check out `REF` and confirm `plutil -extract NSPhotoLibraryAddUsageDescription raw vibetype/Info.plist` prints a description.
1. Boot a simulator with a recent iOS version, e.g. `xcrun simctl boot "iPhone 16"`, and reset its privacy settings with `xcrun simctl privacy booted reset all si.maev.twa`.
1. Build and install the app with `xcodebuild -scheme vibetype -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build build` and `xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/vibetype.app`.
1. Launch it with `xcrun simctl launch --console-pty booted si.maev.twa` and keep the console output for the report.
1. Drive the UI with whatever automation is available, such as XCUITest, `idb`, or direct screen control, and open `GUEST_URL` with `xcrun simctl openurl booted "$GUEST_URL"`.
   If no way to tap inside the simulator is available, stop and report that instead of guessing outcomes.

## Steps

Take a screenshot with `xcrun simctl io booted screenshot <name>.png` after every step and keep it for the report.

1. Accept the invitation on `GUEST_URL` if it is not accepted yet.
1. Tap "Show check in code" and confirm the modal shows a QR code with a white border, a "Share" button, a "Close" button, and no "Print" button.
1. Tap "Share" and confirm the share sheet opens with an image preview and lists "Print" and "Save Image".
1. Tap "Print" in the share sheet and confirm the print options show a preview containing only the QR code, then cancel.
1. Tap "Share" again, then "Save Image", and allow the photo library prompt.
1. Confirm the app is still running with `xcrun simctl spawn booted launchctl list | grep si.maev.twa` and that the console shows no crash.
1. Open the Photos app in the simulator and confirm the saved QR image is there, then export it from `~/Library/Developer/CoreSimulator/Devices/<udid>/data/Media/DCIM` and decode it with `zbarimg` or an equivalent QR decoder to confirm it yields the guest id.
1. Cancel a share sheet without choosing a target and confirm no error toast appears.

## Pass criteria

- The modal shows "Share" and no "Print".
- The share sheet offers "Print" and "Save Image", and the print preview contains only the QR code.
- "Save Image" asks for photo library access, saves the image, and the app keeps running.
- The saved PNG decodes to the guest id and has a visible white border.
- Cancelling the share sheet shows no error.

## Report

Reply with a table of the pass criteria, each marked pass or fail with the evidence file name next to it.
Attach the screenshots, the exported image, and the console log.
Mention the Xcode version, the simulator model and iOS version, and the built commit.
If any step could not run, say which and why instead of guessing its outcome.
