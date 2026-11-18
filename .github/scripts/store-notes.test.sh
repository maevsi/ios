#!/usr/bin/env bash
# Runs store-notes.sh against a throwaway repository.
set -euo pipefail
export LC_ALL=C.UTF-8

script=$(realpath "$(dirname "$0")/store-notes.sh")
cd "$(mktemp -d)"
git init -q
git config user.email test@example.com
git config user.name test

fragment() {
  mkdir -p "store-notes/$1"
  printf '%s\n' "$2" >"store-notes/$1/de-DE.txt"
  printf '%s\n' "$3" >"store-notes/$1/en-US.txt"
  git add store-notes
  git commit -qm "$1"
}
expect() {
  [ "$1" = "$2" ] || {
    printf 'expected: %s\nactual: %s\n' "$2" "$1"
    exit 1
  }
}
fails() {
  if "$script" "$@" >/dev/null 2>&1; then
    echo "expected failure: $*"
    exit 1
  fi
}

fragment old 'Alt' 'Old'
git tag 1.0.0
fragment splash 'Der Startbildschirm ist jetzt hell.' 'The start screen is light now.'
git tag 1.0.1
git commit -q --allow-empty -m deps
git tag 1.0.2
git commit -q --allow-empty -m beta
git tag 1.1.0-beta.1
fragment umlaut "$(printf 'ä%.0s' {1..150})" 'Umlauts count as one character.'
git tag 1.1.0

# The previous release skips prereleases, and the first release has none.
expect "$("$script" previous 1.1.0)" 1.0.2
expect "$("$script" previous 1.0.0)" ''

# Fragments of every release since the previous one, oldest first.
expect "$("$script" notes 1.0.0 1.1.0 de-DE)" "• Der Startbildschirm ist jetzt hell."$'\n'"• $(printf 'ä%.0s' {1..150})"
expect "$("$script" notes 1.0.0 1.1.0 en-US)" $'• The start screen is light now.\n• Umlauts count as one character.'
expect "$("$script" notes 1.0.1 1.0.2 en-US)" ''
fails notes 0.9.0 1.1.0 en-US

# The App Store notes of every locale, which overrides replace, and which need both locales.
expect "$("$script" whatsnew 1.0.0 1.0.1)" '{"de-DE":"• Der Startbildschirm ist jetzt hell.","en-US":"• The start screen is light now."}'
expect "$("$script" whatsnew 1.0.1 1.0.2)" ''
expect "$(RELEASE_NOTES_DE='Neu' RELEASE_NOTES_EN='New' "$script" whatsnew 1.0.1 1.0.2)" '{"de-DE":"Neu","en-US":"New"}'
RELEASE_NOTES_DE='Neu' fails whatsnew 1.0.1 1.0.2
RELEASE_NOTES_DE=$(printf 'x%.0s' {1..4001}) RELEASE_NOTES_EN='New' fails whatsnew 1.0.1 1.0.2

# Releases without fragments leave TestFlight alone, before any call to App Store Connect.
expect "$("$script" testflight 1.0.0)" '::notice::1.0.0 is the first release, so there are no release notes to collect.'
expect "$("$script" testflight 1.0.2)" '::notice::No release since 1.0.1 added release notes, so TestFlight shows none for 1.0.2.'

# Pull requests that release need a fragment, and every fragment needs both locales.
check_pr() { BASE=$1 HEAD=$2 TITLE=$3 AUTHOR=someone SKIP=${4:-false} "$script" pr; }
check_pr 1.0.1 1.0.2 'chore(ci): tidy up'
check_pr 1.0.1 1.0.2 'fix(deps): update' true
check_pr 1.0.2 1.1.0 'feat(ui): add umlauts'
BASE=1.0.1 HEAD=1.0.2 TITLE='fix(deps): update' AUTHOR='renovate[bot]' SKIP=false "$script" pr
BASE=1.0.1 HEAD=1.0.2 TITLE='fix(ui): change color' AUTHOR=someone SKIP=false fails pr
mkdir store-notes/broken
printf 'Kaputt\n' >store-notes/broken/de-DE.txt
fails check store-notes/broken
printf 'One\nTwo\n' >store-notes/broken/en-US.txt
fails check store-notes/broken
printf '%s\n' "$(printf 'x%.0s' {1..151})" >store-notes/broken/en-US.txt
fails check store-notes/broken

echo ok
