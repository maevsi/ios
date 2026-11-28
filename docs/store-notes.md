# Store notes

Every pull request that triggers a release, so every `feat`, `fix`, or `perf`, adds release notes.
They live in `store-notes/<slug>/de-DE.txt` and `store-notes/<slug>/en-US.txt`, one sentence of at most 150 characters per file, written for people who use the app.
The Store notes workflow fails a pull request that triggers a release without adding them, unless it carries the `no-store-notes` label or comes from Renovate.
It also checks every fragment the pull request touches.
The fragments stay in the repository, so they double as a history of what users were told.

## TestFlight

After CI uploads a release to TestFlight, the `release_notes` job collects the fragments added since the previous release, one bullet each.
It waits until App Store Connect has processed the build, then sets the bullets as the build's "What to Test" text in both languages and shows them in the run's summary.
A release that adds no fragments gets a generic text, since external testing requires one.
The job then adds the build to every external TestFlight group of the app and submits it to beta review, after which Apple hands it to the external testers.
An app without external groups only reaches internal testers, and the job warns about that.
Beta review needs the test information in App Store Connect, such as the feedback email and the contact for Apple's reviewers, filled in once.
The job uses the App Store Connect API key from the `testflight` environment, described in [signing.md](signing.md).

When the job fails, rerun it, as it skips what an earlier run did already.
Otherwise add the text, the groups, or the beta review submission by hand in App Store Connect.
The next release does not pick up the fragments of a release whose job failed.

## App Store

After the upload, CI also calls the Promote workflow, which asks App Store Connect which version is on the App Store and collects the fragments added since then, one bullet each.
It shows the collected notes in the run's summary, so read them there before you approve the deployment to the `app-store` environment.
After the approval, it waits until App Store Connect has processed the build, attaches it to the App Store version, sets the notes as "What's New" in both languages, and submits the version to App Store review.
The version goes on sale as soon as Apple approves it.
A release that adds no fragments stays on TestFlight, and the next release that adds some takes it along.
A newer release cancels a submission that still waits for approval, since its notes include the older ones.

Before the first version is on the App Store, every release goes to review without notes, since Apple accepts no "What's New" on an app's first version.
App Store Connect only accepts that submission once the app's store listing is complete, so fill in the description, screenshots, privacy details, age rating, and the other required fields in App Store Connect first.
The submission fails with a list of what is missing otherwise.
The store listing must hold both the German and the English localization, since the workflow sets "What's New" on both and adds no localization of its own.

A version that waits for review or is in review blocks the next one, so the submission of a newer release fails until Apple has decided.
Then run the Promote workflow from `main` once the earlier version is through, which submits the latest release.
The workflow takes its scripts from `main` and only the notes from the release, so after a fix to the scripts, running it again also submits a release whose earlier run failed.
To submit a release without fragments, or with shorter notes, pass your own notes, which replace the collected ones:

```sh
gh workflow run promote.yml --repo maevsi/ios --ref main \
  -f release-notes-de="• Der Startbildschirm passt jetzt zum hellen Design." \
  -f release-notes-en="• The start screen now matches the light design."
```

### Setting up the environment

Create the `app-store` environment, allowed to deploy from `main` only, with yourself as required reviewer:

```sh
gh api -X PUT repos/maevsi/ios/environments/app-store \
  -F 'deployment_branch_policy[protected_branches]=false' \
  -F 'deployment_branch_policy[custom_branch_policies]=true' \
  -F 'reviewers[][type]=User' -F "reviewers[][id]=$(gh api user --jq .id)"
gh api -X POST repos/maevsi/ios/environments/app-store/deployment-branch-policies \
  -f name=main -f type=branch
```

Without reviewers, CI submits every release that adds release notes to App Store review on its own.
Then set the same three `APPSTORE_CONNECT_API_KEY_*` secrets as in the `testflight` environment, as [signing.md](signing.md) describes, with `--env app-store`.

Run `.github/scripts/store-notes.test.sh` after changing `.github/scripts/store-notes.sh`.
