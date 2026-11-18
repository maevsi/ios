#!/usr/bin/env bash
# Checks the store release notes that pull requests add under store-notes/, sends them to TestFlight
# as the "What to Test" text of a release, and submits releases to App Store review with them as
# "What's New". See docs/store-notes.md.
set -euo pipefail
# Without it, a failing API call inside $(...) lets the function go on with an empty response.
shopt -s inherit_errexit
# ${#var} counts bytes in the C locale, which would count each umlaut twice.
export LC_ALL=C.UTF-8

locales=(de-DE en-US)
fragment_limit=150
notes_limit=4000

fail() {
  echo "::error::$*" >&2
  exit 1
}

# check DIR...: each fragment holds exactly one line per locale and nothing else.
check() {
  local dir file locale text
  for dir in "$@"; do
    for file in "$dir"/*; do
      case "${file##*/}" in
        de-DE.txt | en-US.txt) ;;
        *) fail "$file is neither de-DE.txt nor en-US.txt." ;;
      esac
    done
    for locale in "${locales[@]}"; do
      file="$dir/$locale.txt"
      [ -f "$file" ] || fail "$dir lacks $locale.txt."
      text=$(<"$file")
      [ -n "$text" ] || fail "$file is empty."
      [[ $text != *$'\n'* ]] || fail "$file holds more than one line."
      [ "${#text}" -le "$fragment_limit" ] || fail "$file holds ${#text} characters, more than $fragment_limit."
    done
  done
}

# pr: checks the fragments a pull request touches, and requires one for releasing changes.
# Reads BASE, HEAD, TITLE, AUTHOR, and SKIP from the environment.
pr() {
  local list touched=() added
  # Process substitution would swallow a failing git diff, so the list goes through a variable.
  list=$(git diff --diff-filter=d --name-only "$BASE...$HEAD" -- store-notes/ | sed 's|/[^/]*$||' | sort -u)
  [ -z "$list" ] || mapfile -t touched <<<"$list"
  [ "${#touched[@]}" -eq 0 ] || check "${touched[@]}"
  if [[ $TITLE =~ ^(feat|fix|perf)(\(.*\))?!?: ]] && [ "$SKIP" != true ] && [ "$AUTHOR" != 'renovate[bot]' ]; then
    added=$(git diff --diff-filter=A --name-only "$BASE...$HEAD" -- store-notes/)
    [ -n "$added" ] || fail "This pull request triggers a release, so it needs store release notes in store-notes/<slug>/de-DE.txt and en-US.txt, or the no-store-notes label if users notice nothing. See docs/store-notes.md."
  fi
}

# previous TAG: prints the release before tag TAG, skipping prereleases, or nothing for the first one.
previous() {
  git describe --tags --abbrev=0 --exclude '*-*' "refs/tags/$1^" 2>/dev/null || true
}

# collect FROM TO: prints the fragment directories added after tag FROM up to tag TO, oldest first.
collect() {
  local ref
  for ref in "$1" "$2"; do
    git rev-parse -q --verify "refs/tags/$ref" >/dev/null || fail "There is no tag $ref."
  done
  git log --reverse --diff-filter=A --name-only --format= "refs/tags/$1..refs/tags/$2" -- store-notes/ |
    sed 's|/[^/]*$||' | awk '!seen[$0]++' | while read -r dir; do
      # A fragment deleted again before TO no longer describes the release.
      if [ -d "$dir" ]; then echo "$dir"; fi
    done
}

# notes FROM TO LOCALE: prints one bullet per fragment between the tags, or nothing when there are none.
notes() {
  local list dirs=() dir
  list=$(collect "$1" "$2")
  [ -n "$list" ] || return 0
  mapfile -t dirs <<<"$list"
  check "${dirs[@]}"
  for dir in "${dirs[@]}"; do printf '• %s\n' "$(<"$dir/$3.txt")"; done
}

# whatsnew FROM TO: prints the notes of every locale as one line of JSON, from the fragments between
# the tags unless RELEASE_NOTES_DE or RELEASE_NOTES_EN replaces them, or nothing when there are none.
whatsnew() {
  local locale text json='{}' count=0
  for locale in "${locales[@]}"; do
    case "$locale" in
      de-DE) text=${RELEASE_NOTES_DE:-} ;;
      en-US) text=${RELEASE_NOTES_EN:-} ;;
    esac
    [ -n "$text" ] || text=$(notes "$1" "$2" "$locale")
    [ -n "$text" ] || continue
    [ "${#text}" -le "$notes_limit" ] || fail "The $locale release notes hold ${#text} characters, more than $notes_limit."
    json=$(jq -c --arg locale "$locale" --arg text "$text" '. + {($locale): $text}' <<<"$json")
    count=$((count + 1))
  done
  [ "$count" -gt 0 ] || return 0
  [ "$count" -eq "${#locales[@]}" ] || fail "Release notes exist for some locales only. Pass both to the Promote workflow."
  echo "$json"
}

# token: prints a JSON Web Token for the App Store Connect API, valid for the maximum of 20 minutes.
# Reads API_KEY_ID, API_KEY_ISSUER_ID, and API_KEY_PRIVATE_KEY from the environment.
token() {
  # Node signs ES256 in the raw r||s form JWTs need, which OpenSSL only emits as DER.
  node -e '
const crypto = require("crypto");
const b64 = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
// Secrets pasted by hand lose their line breaks or headers, which OpenSSL rejects in a PEM, so the
// key is reduced to its base64 body, or decoded first if the whole file was base64 encoded.
const body = (text) => text.replace(/-----[^-]+-----|\\n|\s/g, "");
let key = Buffer.from(body(process.env.API_KEY_PRIVATE_KEY), "base64");
if (key.toString("latin1").startsWith("-----")) key = Buffer.from(body(key.toString("latin1")), "base64");
const now = Math.floor(Date.now() / 1000);
const data = b64({ alg: "ES256", kid: process.env.API_KEY_ID, typ: "JWT" }) + "." +
  b64({ aud: "appstoreconnect-v1", exp: now + 1200, iat: now, iss: process.env.API_KEY_ISSUER_ID });
const signature = crypto.sign("sha256", Buffer.from(data), {
  dsaEncoding: "ieee-p1363",
  key: crypto.createPrivateKey({ format: "der", key, type: "pkcs8" }),
});
console.log(data + "." + signature.toString("base64url"));
'
}

# api METHOD PATH [BODY]: calls the App Store Connect API with a fresh token.
api() {
  local token args
  token=$(token)
  # -g keeps curl from reading the brackets in filter[...] as a URL range.
  args=(--fail-with-body -gsS -X "$1" -H "Authorization: Bearer $token")
  [ $# -lt 3 ] || args+=(-H 'Content-Type: application/json' --data "$3")
  curl "${args[@]}" "https://api.appstoreconnect.apple.com$2"
}

# app: prints the App Store Connect ID of the app with the bundle ID BUNDLE_ID.
app() {
  local id
  id=$(api GET "/v1/apps?filter[bundleId]=$BUNDLE_ID" | jq -r '.data[0].id // empty')
  [ -n "$id" ] || fail "App Store Connect has no app with the bundle ID $BUNDLE_ID."
  echo "$id"
}

# build APP TAG: prints the ID of the latest build of TAG once App Store Connect has processed it.
build() {
  local response id state
  # The build shows up some minutes after the upload, and the job's timeout ends the wait.
  while :; do
    response=$(api GET "/v1/builds?filter[app]=$1&filter[preReleaseVersion.version]=$2&sort=-uploadedDate&limit=1")
    id=$(jq -r '.data[0].id // empty' <<<"$response")
    state=$(jq -r '.data[0].attributes.processingState // empty' <<<"$response")
    case "$state" in
      VALID)
        echo "$id"
        return 0
        ;;
      FAILED | INVALID) fail "App Store Connect could not process the build $id of $2: $state." ;;
    esac
    echo "Waiting for the build of $2${state:+, now $state}." >&2
    sleep 60
  done
}

# live: prints the version on sale on the App Store, or nothing before the first one.
live() {
  local app
  app=$(app)
  # appVersionState replaces the deprecated appStoreState, so either may carry the state.
  api GET "/v1/apps/$app/appStoreVersions?filter[platform]=IOS&limit=200" |
    jq -r '[.data[] | select(.attributes.appVersionState == "READY_FOR_DISTRIBUTION" or .attributes.appStoreState == "READY_FOR_SALE")][0].attributes.versionString // empty'
}

# localize LIST TYPE RELATIONSHIP ID NOTES: sets whatsNew per locale of the JSON object NOTES, on the
# localizations in the API response LIST, creating those that are missing if RELATIONSHIP is given.
localize() {
  local list=$1 type=$2 relationship=$3 parent=$4 notes=$5 locale text id body
  for locale in "${locales[@]}"; do
    text=$(jq -r --arg locale "$locale" '.[$locale]' <<<"$notes")
    id=$(jq -r --arg locale "$locale" '.data[] | select(.attributes.locale == $locale) | .id' <<<"$list")
    if [ -n "$id" ]; then
      body=$(jq -n --arg type "$type" --arg id "$id" --arg text "$text" \
        '{data: {type: $type, id: $id, attributes: {whatsNew: $text}}}')
      api PATCH "/v1/$type/$id" "$body" >/dev/null
    elif [ -n "$relationship" ]; then
      body=$(jq -n --arg type "$type" --arg relationship "$relationship" --arg parent "$parent" --arg locale "$locale" --arg text "$text" \
        '{data: {type: $type, attributes: {locale: $locale, whatsNew: $text}, relationships: {($relationship): {data: {type: ($relationship + "s"), id: $parent}}}}}')
      api POST "/v1/$type" "$body" >/dev/null
    else
      fail "The App Store version lacks the $locale localization, so add it in App Store Connect."
    fi
    printf '### %s\n\n%s\n\n' "$locale" "$text" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
  done
}

# testflight TAG: sets the fragments since the previous release as "What to Test" of the build for TAG.
# Waits until App Store Connect has processed the build. Reads BUNDLE_ID and the variables of token.
testflight() {
  local tag=$1 from notes app build list
  from=$(previous "$tag")
  if [ -z "$from" ]; then
    echo "::notice::$tag is the first release, so there are no release notes to collect."
    return 0
  fi
  notes=$(whatsnew "$from" "$tag")
  if [ -z "$notes" ]; then
    echo "::notice::No release since $from added release notes, so TestFlight shows none for $tag."
    return 0
  fi
  # Assignments, unlike arguments, pass a failing command substitution on to set -e.
  app=$(app)
  build=$(build "$app" "$tag")
  list=$(api GET "/v1/builds/$build/betaBuildLocalizations")
  localize "$list" betaBuildLocalizations build "$build" "$notes"
  echo "Set the release notes collected since $from on the TestFlight build of $tag."
}

# submit TAG: submits the build of TAG to App Store review, to go on sale once Apple approves it.
# Sets the JSON object NOTES from the environment as "What's New", unless it is empty, as on the
# first version, which takes none. Reads BUNDLE_ID and the variables of token.
submit() {
  local tag=$1 app build attributes version body list submission
  app=$(app)
  build=$(build "$app" "$tag")
  attributes=$(jq -n --arg tag "$tag" '{versionString: $tag, releaseType: "AFTER_APPROVAL"}')
  # An app has at most one version that is not yet submitted, which a newer release takes over.
  version=$(api GET "/v1/apps/$app/appStoreVersions?filter[platform]=IOS&limit=200" |
    jq -r '[.data[] | select(.attributes.appStoreState | IN("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"))][0].id // empty')
  if [ -n "$version" ]; then
    body=$(jq -n --arg id "$version" --argjson attributes "$attributes" '{data: {type: "appStoreVersions", id: $id, attributes: $attributes}}')
    api PATCH "/v1/appStoreVersions/$version" "$body" >/dev/null
  else
    body=$(jq -n --arg app "$app" --argjson attributes "$attributes" \
      '{data: {type: "appStoreVersions", attributes: ($attributes + {platform: "IOS"}), relationships: {app: {data: {type: "apps", id: $app}}}}}')
    version=$(api POST /v1/appStoreVersions "$body" | jq -r .data.id)
  fi
  body=$(jq -n --arg build "$build" '{data: {type: "builds", id: $build}}')
  api PATCH "/v1/appStoreVersions/$version/relationships/build" "$body" >/dev/null
  if [ -n "${NOTES:-}" ]; then
    list=$(api GET "/v1/appStoreVersions/$version/appStoreVersionLocalizations")
    localize "$list" appStoreVersionLocalizations '' "$version" "$NOTES"
  fi
  # A submission left unsubmitted by an earlier run would block a new one, so it is reused.
  submission=$(api GET "/v1/reviewSubmissions?filter[app]=$app&filter[platform]=IOS&filter[state]=READY_FOR_REVIEW" | jq -r '.data[0].id // empty')
  if [ -z "$submission" ]; then
    body=$(jq -n --arg app "$app" '{data: {type: "reviewSubmissions", attributes: {platform: "IOS"}, relationships: {app: {data: {type: "apps", id: $app}}}}}')
    submission=$(api POST /v1/reviewSubmissions "$body" | jq -r .data.id)
  fi
  list=$(api GET "/v1/reviewSubmissions/$submission/items?include=appStoreVersion")
  if ! jq -e --arg version "$version" 'any(.data[]; .relationships.appStoreVersion.data.id == $version)' <<<"$list" >/dev/null; then
    body=$(jq -n --arg submission "$submission" --arg version "$version" \
      '{data: {type: "reviewSubmissionItems", relationships: {reviewSubmission: {data: {type: "reviewSubmissions", id: $submission}}, appStoreVersion: {data: {type: "appStoreVersions", id: $version}}}}}')
    api POST /v1/reviewSubmissionItems "$body" >/dev/null
  fi
  body=$(jq -n --arg id "$submission" '{data: {type: "reviewSubmissions", id: $id, attributes: {submitted: true}}}')
  api PATCH "/v1/reviewSubmissions/$submission" "$body" >/dev/null
  echo "Submitted $tag to App Store review."
}

case "${1:-}" in
  check | collect | live | notes | pr | previous | submit | testflight | token | whatsnew)
    command=$1
    shift
    "$command" "$@"
    ;;
  *) fail "Usage: $0 check DIR... | collect FROM TO | live | notes FROM TO LOCALE | pr | previous TAG | submit TAG | testflight TAG | token | whatsnew FROM TO" ;;
esac
