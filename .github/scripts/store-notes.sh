#!/usr/bin/env bash
# Checks the store release notes that pull requests add under store-notes/, and sends them to
# TestFlight as the "What to Test" text of a release. See docs/store-notes.md.
set -euo pipefail
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
  local list dirs=() dir text
  list=$(collect "$1" "$2")
  [ -n "$list" ] || return 0
  mapfile -t dirs <<<"$list"
  check "${dirs[@]}"
  text=$(for dir in "${dirs[@]}"; do printf '• %s\n' "$(<"$dir/$3.txt")"; done)
  [ "${#text}" -le "$notes_limit" ] || fail "The $3 release notes hold ${#text} characters, more than $notes_limit."
  printf '%s' "$text"
}

# token: prints a JSON Web Token for the App Store Connect API, valid for the maximum of 20 minutes.
# Reads API_KEY_ID, API_KEY_ISSUER_ID, and API_KEY_PRIVATE_KEY from the environment.
token() {
  # Node signs ES256 in the raw r||s form JWTs need, which OpenSSL only emits as DER.
  node -e '
const crypto = require("crypto");
const b64 = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
const now = Math.floor(Date.now() / 1000);
const data = b64({ alg: "ES256", kid: process.env.API_KEY_ID, typ: "JWT" }) + "." +
  b64({ aud: "appstoreconnect-v1", exp: now + 1200, iat: now, iss: process.env.API_KEY_ISSUER_ID });
const signature = crypto.sign("sha256", Buffer.from(data), { dsaEncoding: "ieee-p1363", key: process.env.API_KEY_PRIVATE_KEY });
console.log(data + "." + signature.toString("base64url"));
'
}

# api METHOD PATH [BODY]: calls the App Store Connect API with a fresh token.
api() {
  # -g keeps curl from reading the brackets in filter[...] as a URL range.
  local args=(--fail-with-body -gsS -X "$1" -H "Authorization: Bearer $(token)")
  [ $# -lt 3 ] || args+=(-H 'Content-Type: application/json' --data "$3")
  curl "${args[@]}" "https://api.appstoreconnect.apple.com$2"
}

# testflight TAG: sets the fragments since the previous release as "What to Test" of the build for TAG.
# Waits until App Store Connect has processed the build. Reads BUNDLE_ID and the variables of token.
testflight() {
  local tag=$1 from locale text app response build state existing id body
  local -A texts=()
  from=$(previous "$tag")
  if [ -z "$from" ]; then
    echo "::notice::$tag is the first release, so there are no release notes to collect."
    return 0
  fi
  for locale in "${locales[@]}"; do
    text=$(notes "$from" "$tag" "$locale")
    [ -z "$text" ] || texts[$locale]=$text
  done
  if [ "${#texts[@]}" -eq 0 ]; then
    echo "::notice::No release since $from added release notes, so TestFlight shows none for $tag."
    return 0
  fi
  app=$(api GET "/v1/apps?filter[bundleId]=$BUNDLE_ID" | jq -r '.data[0].id // empty')
  [ -n "$app" ] || fail "App Store Connect has no app with the bundle ID $BUNDLE_ID."
  # The build shows up some minutes after the upload, and the job's timeout ends the wait.
  while :; do
    response=$(api GET "/v1/builds?filter[app]=$app&filter[preReleaseVersion.version]=$tag&sort=-uploadedDate&limit=1")
    build=$(jq -r '.data[0].id // empty' <<<"$response")
    state=$(jq -r '.data[0].attributes.processingState // empty' <<<"$response")
    case "$state" in
      VALID) break ;;
      FAILED | INVALID) fail "App Store Connect could not process the build $build of $tag: $state." ;;
    esac
    echo "Waiting for the build of $tag${state:+, now $state}."
    sleep 60
  done
  existing=$(api GET "/v1/builds/$build/betaBuildLocalizations")
  for locale in "${locales[@]}"; do
    [ -n "${texts[$locale]:-}" ] || continue
    id=$(jq -r --arg locale "$locale" '.data[] | select(.attributes.locale == $locale) | .id' <<<"$existing")
    if [ -n "$id" ]; then
      body=$(jq -n --arg id "$id" --arg notes "${texts[$locale]}" \
        '{data: {type: "betaBuildLocalizations", id: $id, attributes: {whatsNew: $notes}}}')
      api PATCH "/v1/betaBuildLocalizations/$id" "$body" >/dev/null
    else
      body=$(jq -n --arg build "$build" --arg locale "$locale" --arg notes "${texts[$locale]}" \
        '{data: {type: "betaBuildLocalizations", attributes: {locale: $locale, whatsNew: $notes}, relationships: {build: {data: {type: "builds", id: $build}}}}}')
      api POST /v1/betaBuildLocalizations "$body" >/dev/null
    fi
    printf '### %s\n\n%s\n\n' "$locale" "${texts[$locale]}" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
  done
  echo "Set the release notes collected since $from on the TestFlight build of $tag."
}

case "${1:-}" in
  check | collect | notes | pr | previous | testflight)
    command=$1
    shift
    "$command" "$@"
    ;;
  *) fail "Usage: $0 check DIR... | collect FROM TO | notes FROM TO LOCALE | pr | previous TAG | testflight TAG" ;;
esac
