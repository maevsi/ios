# Store notes

Every pull request that triggers a release, so every `feat`, `fix`, or `perf`, adds release notes.
They live in `store-notes/<slug>/de-DE.txt` and `store-notes/<slug>/en-US.txt`, one sentence of at most 150 characters per file, written for people who use the app.
The Store notes workflow fails a pull request that triggers a release without adding them, unless it carries the `no-store-notes` label or comes from Renovate.
It also checks every fragment the pull request touches.
The fragments stay in the repository, so they double as a history of what users were told.

## TestFlight

After CI uploads a release to TestFlight, the `release_notes` job collects the fragments added since the previous release, one bullet each.
It waits until App Store Connect has processed the build, then sets the bullets as the build's "What to Test" text in both languages and shows them in the run's summary.
A release that adds no fragments gets no text.
The job uses the App Store Connect API key from the `testflight` environment, described in [signing.md](signing.md).

When the job fails, the build stays on TestFlight without text, and you can add it by hand in App Store Connect.
The next release does not pick up the fragments of a release whose job failed.

Run `.github/scripts/store-notes.test.sh` after changing `.github/scripts/store-notes.sh`.
