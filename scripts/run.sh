#!/usr/bin/env bash
#
# WeWere build & run
#
#   ./scripts/run.sh                 build + launch on the iOS Simulator
#   ./scripts/run.sh --device        build + install + launch on a connected iPhone
#   ./scripts/run.sh --sim "iPhone 17 Pro"   pick a specific simulator
#   ./scripts/run.sh --build-only    compile only, don't install or launch
#   ./scripts/run.sh --clean         wipe DerivedData first
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP_ENVIRONMENT="staging"
SCHEME="WeWere"
CONFIGURATION="Debug"
BUNDLE_ID="com.wewere.app"
PROJECT="WeWere.xcodeproj"
DERIVED="build/DerivedData"

SIM_NAME=""
TARGET="sim"
BUILD_ONLY=0
CLEAN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)        APP_ENVIRONMENT="${2:?--env requires staging or production}"; shift 2 ;;
    --device)     TARGET="device"; shift ;;
    --sim)        SIM_NAME="$2"; shift 2 ;;
    --build-only) BUILD_ONLY=1; shift ;;
    --clean)      CLEAN=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

case "$APP_ENVIRONMENT" in
  staging) SCHEME="WeWere-Staging"; CONFIGURATION="StagingDebug"; BUNDLE_ID="com.wewere.app.staging" ;;
  production) ;;
  *) echo "error: --env must be staging or production" >&2; exit 2 ;;
esac
if [[ "$APP_ENVIRONMENT" == "staging" && ! -f WeWere/StagingSecrets.swift ]]; then
  echo "error: missing WeWere/StagingSecrets.swift; see docs/APP_ENVIRONMENTS.md" >&2
  exit 1
fi
echo "==> environment: $APP_ENVIRONMENT"

# --- toolchain ---------------------------------------------------------------
# Prefer whatever xcode-select points at; fall back to /Applications/Xcode.app.
if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
  if [[ -d /Applications/Xcode.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    echo "error: no Xcode.app found. Install Xcode from the App Store." >&2
    exit 1
  fi
fi

# xcodebuild -version exits 0 even when its libraries fail to load, so check
# the output itself and confirm simctl actually resolves.
_xb_out=$(xcodebuild -version 2>&1 || true)
if grep -q "Error loading required libraries" <<<"$_xb_out" || ! xcrun -f simctl >/dev/null 2>&1; then
  _mac=$(sw_vers -productVersion)
  _xc=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
          "$(xcode-select -p 2>/dev/null | sed 's|/Contents/Developer||')/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Xcode.app/Contents/Info.plist 2>/dev/null \
        || echo '?')
  cat >&2 <<EOF
error: the Xcode toolchain is not usable.
       macOS $_mac  +  Xcode $_xc

       Xcode $_xc predates this macOS, so its private frameworks fail to link
       against the system ones. Builds cannot run until Xcode is updated.

       Fix: install the Xcode that matches macOS $_mac (App Store, or
       https://developer.apple.com/download/all/), then:
           sudo xcode-select -s /Applications/Xcode.app
           sudo xcodebuild -runFirstLaunch
EOF
  exit 1
fi

if [[ ! -f WeWere/Secrets.swift ]]; then
  echo "error: WeWere/Secrets.swift is missing (gitignored). Restore it before building." >&2
  exit 1
fi

# --- generate project --------------------------------------------------------
echo "==> xcodegen"
xcodegen generate --spec project.yml

[[ $CLEAN -eq 1 ]] && { echo "==> cleaning $DERIVED"; rm -rf "$DERIVED"; }

# --- build -------------------------------------------------------------------
if [[ "$TARGET" == "sim" ]]; then
  if [[ -z "$SIM_NAME" ]]; then
    # Newest available iPhone: rank by runtime version, then model number, then
    # tier (Pro Max > Pro > Plus > base). Sorting names as plain strings would
    # rank "iPhone SE" above "iPhone 17 Pro", so parse the model number out.
    SIM_NAME=$(xcrun simctl list devices available -j \
      | python3 -c "
import json,sys,re
d=json.load(sys.stdin)['devices']
def tier(n):
    if 'Pro Max' in n: return 3
    if 'Pro' in n:     return 2
    if 'Plus' in n:    return 1
    return 0
best=None
for rt,devs in d.items():
    if 'iOS' not in rt: continue
    ver=tuple(int(x) for x in re.findall(r'\d+', rt.rsplit('iOS-',1)[-1]))
    for dev in devs:
        n=dev['name']
        if not n.startswith('iPhone'): continue
        m=re.search(r'iPhone\s+(\d+)', n)
        if not m: continue          # skips SE / non-numbered models
        key=(ver, int(m.group(1)), tier(n))
        if best is None or key>best[0]: best=(key,n)
print(best[1] if best else '')")
  fi
  [[ -z "$SIM_NAME" ]] && { echo "error: no iPhone simulator available." >&2; exit 1; }
  echo "==> building for simulator: $SIM_NAME"
  DEST="platform=iOS Simulator,name=$SIM_NAME"
  # Simulator builds still need an ad-hoc signature for Keychain access.
  EXTRA=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-)
else
  echo "==> building for connected device"
  DEST="generic/platform=iOS"
  EXTRA=(-allowProvisioningUpdates)
fi

# -quiet already limits output to diagnostics + the result line. Without it the
# raw log is tens of thousands of lines of clang invocations, and naive greps
# match inside them (e.g. "EagerLinkingTBDs" contains "Linking").
set -o pipefail
if command -v xcbeautify >/dev/null; then
  FMT=(xcbeautify)
else
  # Dedupe repeated diagnostics; the Swift driver emits each one per batch job.
  FMT=(awk '!seen[$0]++')
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" \
  "${EXTRA[@]}" \
  -quiet \
  build \
  | "${FMT[@]}"

[[ $BUILD_ONLY -eq 1 ]] && { echo "==> build only, done."; exit 0; }

# --- locate .app -------------------------------------------------------------
if [[ "$TARGET" == "sim" ]]; then
  APP="$DERIVED/Build/Products/$CONFIGURATION-iphonesimulator/WeWere.app"
else
  APP="$DERIVED/Build/Products/$CONFIGURATION-iphoneos/WeWere.app"
fi
[[ ! -d "$APP" ]] && { echo "error: built .app not found under $DERIVED" >&2; exit 1; }
echo "==> app: $APP"

# --- install & launch --------------------------------------------------------
if [[ "$TARGET" == "sim" ]]; then
  UDID=$(xcrun simctl list devices available -j \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
for rt,devs in d.items():
    for dev in devs:
        if dev['name']=='$SIM_NAME': print(dev['udid']); raise SystemExit")
  echo "==> booting $SIM_NAME ($UDID)"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  open -a Simulator --args -CurrentDeviceUDID "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
  echo "==> installing"
  xcrun simctl install "$UDID" "$APP"
  echo "==> launching $BUNDLE_ID"
  xcrun simctl launch "$UDID" "$BUNDLE_ID"
else
  DEV_ID=$(xcrun devicectl list devices -j /dev/stdout 2>/dev/null \
    | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit
for dev in d.get('result',{}).get('devices',[]):
    props=dev.get('deviceProperties',{})
    conn=dev.get('connectionProperties',{})
    if conn.get('tunnelState') in ('connected','available') or props.get('developerModeStatus')=='enabled':
        print(dev['identifier']); raise SystemExit")
  [[ -z "$DEV_ID" ]] && { echo "error: no connected device found. Unlock the iPhone and trust this Mac." >&2; exit 1; }
  echo "==> installing on device $DEV_ID"
  xcrun devicectl device install app --device "$DEV_ID" "$APP"
  echo "==> launching $BUNDLE_ID"
  xcrun devicectl device process launch --device "$DEV_ID" "$BUNDLE_ID"
fi

echo "==> done."
