# App Review

This file records how the app meets the [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) and what to recheck when something changes.
The app wraps the web app [maevsi/vibetype](https://github.com/maevsi/vibetype), so App Review judges both, and some rows point there.

Last full check: 2026-11-22, against the guidelines last updated on 2026-10-16.

## Status

| Guideline | How the app meets it | Recheck when |
| --- | --- | --- |
| 1.2 User-generated content | The web app lets people report events (`EventReportForm.vue`), block accounts (`AccountBlockDrawer.vue`), and reach the team through `/contact` and `/support/report`. Uploaded poster images pass OpenAI's moderation (`image.post.ts`), and with maevsi/postgraphile#74 so do event names, descriptions, and profile text, in front of every GraphQL mutation (`src/presets/moderation.ts`), failing closed when OpenAI is unreachable. | Reporting, blocking, or filtering changes in the web app. |
| 2.1 App completeness | The review notes in App Store Connect carry a demo account, since most features need one. | The demo account's password or data changes. |
| 2.5.1 Public APIs only | The app sets no private `WKPreferences` keys and calls no private selectors. | Anything uses `setValue(_:forKey:)` or `perform(_:)` on a system class. |
| 2.5.6 Web browsing | All web content runs in `WKWebView`, and pages outside `vibetype.app` open in `SFSafariViewController`, which 5.1.1(vii) requires to stay visible and not to track. | `WebView.swift` changes its navigation policy. |
| 4.2 Minimum functionality | Beyond the web app, the app brings push notifications, the document camera for posters, the share extension, the contact picker, printing, and a home screen shortcut. The review notes list them. | A native feature goes away, or a new one comes. |
| 4.5.4 Push notifications | The app asks for permission only when the web app requests it, and nothing depends on it. | `PushNotifications.swift` or the web app's notification step changes. |
| 4.8 Login services | The app signs people in only with their own Vibetype account, which needs no other login service. Once a third-party login such as Google ships, the app must also offer an equivalent one that limits data to name and email, can hide the email, and does not track for advertising, which Sign in with Apple does. | A sign-in provider is added. |
| 5.1.1(i) Privacy policy | The web app serves it at `/docs/legal/privacy`, links it from the start page and the account settings, and App Store Connect links it too. It names Google Analytics, Sentry, and OpenAI. Open: Firebase Cloud Messaging is only described in the draft rewrite maevsi/vibetype#2697. | The policy URL changes, or a third party gets user data. |
| 5.1.1(ii) Permissions | `Info.plist` has purpose strings for the camera and location, in English and in German through `de.lproj/InfoPlist.strings`. The contact picker needs none, as 5.1.1(iii) prefers. Declining location still leaves the event form's free-text location field, as 5.1.1(iv) asks. | A new permission is requested natively or through the web view. |
| 5.1.1(v) Account deletion | The web app offers it in the account settings (`AccountDeleteDrawer.vue`). | Account settings change. |
| 5.1.2(i) Third-party AI | With maevsi/vibetype#2808, poster hunting asks before the first poster photo or page text goes to OpenAI, the ingest endpoints refuse without that permission, and the privacy settings withdraw it. | A feature sends user content to an outside service. |
| 5.1.2 Tracking | The app does not track, so it shows no App Tracking Transparency prompt and `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking` as false. Only `FirebaseMessaging` is linked, and the web app's Google Analytics runs without ad signals. | A Firebase product or SDK is added, or the web app's analytics settings change. |
| Privacy manifest | Not a guideline, but App Store Connect rejects uploads without it. `PrivacyInfo.xcprivacy` declares the file timestamp API that `takeSharedPoster` in `PosterShare.swift` uses, with reason `C617.1`. | Code uses an API from Apple's [required reason list](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). |
| App privacy labels | Unverified: App Store Connect must declare the push token as a device ID used for app functionality and not for tracking. | The data the app or the web app collects changes. |

## Social login in the app

The social login buttons in the web app have no flow behind them yet, so this applies once they do.
The web view only navigates within `WKAppBoundDomains`, so it hands `appleid.apple.com` and `accounts.google.com` to `SFSafariViewController`, which shares no cookies with the web view.
A sign-in started there never reaches the app's session, which App Review rejects under guideline 2.1.
Google also refuses OAuth inside embedded web views.
Guideline 5.1.1(v) then also asks for a way in the app to revoke the social login and stop the data access.
The native side therefore needs to run the provider's page in `ASWebAuthenticationSession` and load the callback URL in the web view, or the web app needs to sign in through a native bridge such as `ASAuthorizationAppleIDProvider` for Apple.

## Rechecking

Compare the guidelines' last updated date at the bottom of the page with the one above, read what changed since, then go through the table, check off the unverified rows, and update the date.
Do this before submitting a version that adds a native feature, a permission, an SDK, or a sign-in provider, and once a year otherwise.
