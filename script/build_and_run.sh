#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Scroll Reverser Dev"
BUNDLE_ID="com.alexjiang.ScrollReverser.dev"
TEAM_ID="72UN4PF4BL"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/ScrollReverser.xcodeproj"
DERIVED_DATA="/private/tmp/ScrollReverserDevDerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
INSTALLED_APP="/Applications/$APP_NAME.app"
STAGING_APP="/Applications/.$APP_NAME.staging.app"
PREVIOUS_APP="/Applications/.$APP_NAME.previous.app"

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify) ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  elif [[ -d "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
    DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
  else
    echo "Full Xcode is required" >&2
    exit 1
  fi
fi

export DEVELOPER_DIR

validate_identity() {
  local app_bundle="$1"
  local actual_bundle_id
  local signing_details

  test -d "$app_bundle" || return 1
  codesign --verify --deep --strict --verbose=4 "$app_bundle" || return 1
  actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_bundle/Contents/Info.plist")" || return 1
  test "$actual_bundle_id" = "$BUNDLE_ID" || return 1
  signing_details="$(codesign -dvvv -r- "$app_bundle" 2>&1)" || return 1
  grep -F "TeamIdentifier=$TEAM_ID" <<<"$signing_details" >/dev/null || return 1
  grep -F "Authority=Apple Development:" <<<"$signing_details" >/dev/null || return 1
  grep -F "designated => identifier \"$BUNDLE_ID\"" <<<"$signing_details" >/dev/null || return 1
}

had_installed_app=0
promotion_started=0
restore_install() {
  local status=$?
  if [[ -e "$PREVIOUS_APP" ]]; then
    rm -rf "$INSTALLED_APP"
    mv "$PREVIOUS_APP" "$INSTALLED_APP"
  elif [[ "$had_installed_app" = 0 && "$promotion_started" = 1 ]]; then
    rm -rf "$INSTALLED_APP"
  fi
  rm -rf "$STAGING_APP"
  return "$status"
}

# Resolve leftovers from an earlier interrupted install before arming the
# promotion rollback. A stale backup must never replace a valid current app.
if [[ -e "$PREVIOUS_APP" ]]; then
  if [[ ! -e "$INSTALLED_APP" ]]; then
    validate_identity "$PREVIOUS_APP" || {
      echo "Previous app backup has an invalid identity: $PREVIOUS_APP" >&2
      exit 1
    }
    mv "$PREVIOUS_APP" "$INSTALLED_APP"
  else
    validate_identity "$INSTALLED_APP" || {
      echo "Installed app is invalid; preserving backup at $PREVIOUS_APP" >&2
      exit 1
    }
    rm -rf "$PREVIOUS_APP"
  fi
fi

trap restore_install EXIT
trap 'exit 130' INT TERM HUP

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "Scroll Reverser" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Development" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  build

validate_identity "$BUILT_APP"

rm -rf "$STAGING_APP"
/usr/bin/ditto "$BUILT_APP" "$STAGING_APP"
validate_identity "$STAGING_APP"

if [[ -e "$INSTALLED_APP" ]]; then
  had_installed_app=1
  mv "$INSTALLED_APP" "$PREVIOUS_APP"
fi
promotion_started=1
if ! mv "$STAGING_APP" "$INSTALLED_APP"; then
  exit 1
fi
if ! validate_identity "$INSTALLED_APP"; then
  exit 1
fi
promotion_started=0
rm -rf "$PREVIOUS_APP"

open_app() {
  /usr/bin/open -n "$INSTALLED_APP"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$INSTALLED_APP/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    launched_pid="$(pgrep -n -x "$APP_NAME")"
    test -n "$launched_pid"
    ps -p "$launched_pid" -o command= | grep -F "$INSTALLED_APP/Contents/MacOS/$APP_NAME" >/dev/null
    runtime_identity="$(/usr/bin/log show --last 30s --style compact --predicate "processIdentifier == $launched_pid AND eventMessage CONTAINS \"runtime identity:\"" | tail -n 1)"
    echo "$runtime_identity"
    grep -F "accessibilityTrusted=1" <<<"$runtime_identity" >/dev/null
    grep -F "stableLaunchPathMatched=1" <<<"$runtime_identity" >/dev/null
    recovery_probe="$(/usr/bin/log show --last 30s --style compact --predicate "processIdentifier == $launched_pid AND eventMessage CONTAINS \"tap disable-handler probe:\"" | tail -n 1)"
    echo "$recovery_probe"
    grep -F "disabledThenReenabled=1" <<<"$recovery_probe" >/dev/null
    ;;
esac
