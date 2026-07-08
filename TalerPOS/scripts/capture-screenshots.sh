#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Defaults
BASE_DIR="$REPO_ROOT/TalerPOS/build/screenshots"
ONLY_SCENARIOS=""

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--scenario)
      ONLY_SCENARIOS="$2"
      shift 2
      ;;
    -o|--output)
      BASE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [options]"
      echo ""
      echo "Options:"
      echo "  -s, --scenario <name>   Run only the specified scenario(s), comma-separated"
      echo "                          e.g. -s history  or  -s login,mfa-select,mfa-code"
      echo "  -o, --output <dir>      Output directory (default: TalerPOS/build/screenshots)"
      echo "  -h, --help              Show this help"
      echo ""
      echo "Scenarios: login, mfa-select, mfa-code, amount-entry, order, order-custom,"
      echo "           order-custom-added, payment, payment-success, history, refund,"
      echo "           refund-qr, navigation"
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (use -h for help)" >&2
      exit 1
      ;;
  esac
done

# Auto-detect simulators
echo "Auto-detecting available simulators..."
SIMULATORS=()
IPHONE=$(xcodebuild -project "$REPO_ROOT/TalerPOS.xcodeproj" -scheme TalerPOS -showdestinations 2>/dev/null \
  | grep 'platform:iOS Simulator' | grep 'name:iPhone' \
  | sed 's/.*name:\([^,}]*\).*/\1/' | sed 's/ *$//' | sort -u | tail -1)
IPAD=$(xcodebuild -project "$REPO_ROOT/TalerPOS.xcodeproj" -scheme TalerPOS -showdestinations 2>/dev/null \
  | grep 'platform:iOS Simulator' | grep 'name:iPad' | grep '11-inch' \
  | sed 's/.*name:\([^,}]*\).*/\1/' | sed 's/ *$//' | sort -u | tail -1)
[[ -n "$IPHONE" ]] && SIMULATORS+=("$IPHONE")
[[ -n "$IPAD" ]] && SIMULATORS+=("$IPAD")

if [[ ${#SIMULATORS[@]} -eq 0 ]]; then
  echo "No simulators found." >&2
  exit 1
fi
echo "  Found: ${SIMULATORS[*]}"
echo ""

LOCALES=("en" "de" "fr")

# Read version from the Xcode project
VERSION=$(grep 'MARKETING_VERSION' "$REPO_ROOT/TalerPOS.xcodeproj/project.pbxproj" \
  | head -1 | sed 's/.*= *"\{0,1\}\([^";]*\)"\{0,1\}.*/\1/' | tr -d ' ')
VERSION="${VERSION:-unknown}"

# Ensure scheme includes TalerPOSUITests (Xcode sometimes strips it)
SCHEME_FILE="$REPO_ROOT/TalerPOS.xcodeproj/xcshareddata/xcschemes/TalerPOS.xcscheme"
if ! grep -q 'BlueprintName = "TalerPOSUITests"' "$SCHEME_FILE" 2>/dev/null; then
  echo "Injecting TalerPOSUITests into scheme..."
  UI_TEST_REF='         <TestableReference\
            skipped = "NO">\
            <BuildableReference\
               BuildableIdentifier = "primary"\
               BlueprintIdentifier = "E5000001"\
               BuildableName = "TalerPOSUITests.xctest"\
               BlueprintName = "TalerPOSUITests"\
               ReferencedContainer = "container:TalerPOS.xcodeproj">\
            <\/BuildableReference>\
         <\/TestableReference>'
  sed -i '' "/<\/Testables>/i\\
$UI_TEST_REF
" "$SCHEME_FILE"
fi

# Build test target to pick the right test method
if [[ -n "$ONLY_SCENARIOS" ]]; then
  TEST_TARGET="-only-testing:TalerPOSUITests/ScreenshotTests/testSelectedScenarios"
  echo "=== Capturing scenario(s): $ONLY_SCENARIOS ==="
else
  TEST_TARGET="-only-testing:TalerPOSUITests/ScreenshotTests/testAllScreenshots"
  echo "=== Capturing all screenshots for version $VERSION ==="
fi
echo ""

for SIMULATOR in "${SIMULATORS[@]}"; do
  echo "--- Device: $SIMULATOR ---"

  # Sanitize device name for folder (spaces -> underscores, lowercase)
  DEVICE_FOLDER=$(echo "$SIMULATOR" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')

  # Boot simulator and override status bar to 9:41
  SIM_UDID=$(xcrun simctl list devices available | grep "$SIMULATOR" | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
  if [[ -n "$SIM_UDID" ]]; then
    xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
    sleep 3
    xcrun simctl status_bar "$SIM_UDID" override \
      --time "9:41" \
      --batteryState charged \
      --batteryLevel 100 \
      --cellularBars 4 \
      --wifiBars 3
    echo "  Status bar set to 9:41 on $SIM_UDID"
  fi

  for LOCALE in "${LOCALES[@]}"; do
    echo "  === Locale: $LOCALE ==="

    DEVICE_DIR="$BASE_DIR/$VERSION/$DEVICE_FOLDER/$LOCALE"
    mkdir -p "$DEVICE_DIR"

    RESULT_BUNDLE="$DEVICE_DIR/ScreenshotTests.xcresult"
    rm -rf "$RESULT_BUNDLE"

    TMPDIR_EXPORT=$(mktemp -d)

    SCREENSHOT_LOCALE="$LOCALE" SCREENSHOT_SCENARIOS="$ONLY_SCENARIOS" xcodebuild test \
      -project "$REPO_ROOT/TalerPOS.xcodeproj" \
      -scheme TalerPOS \
      -destination "platform=iOS Simulator,name=$SIMULATOR" \
      $TEST_TARGET \
      -resultBundlePath "$RESULT_BUNDLE" \
      | grep -E '(Test Case|Test Suite|error:|BUILD|Failing)' || true

    echo ""

    # Export attachments + manifest
    xcrun xcresulttool export attachments \
      --path "$RESULT_BUNDLE" \
      --output-path "$TMPDIR_EXPORT"

    # Use manifest.json to rename files by scenario name
    if [[ -f "$TMPDIR_EXPORT/manifest.json" ]]; then
      python3 -c "
import json, shutil, os
manifest = json.load(open('$TMPDIR_EXPORT/manifest.json'))
for entry in manifest:
    for att in entry.get('attachments', []):
        exported = att.get('exportedFileName', '')
        suggested = att.get('suggestedHumanReadableName', '')
        scenario = suggested.split('_0_')[0] if '_0_' in suggested else suggested.rsplit('.', 1)[0]
        src = os.path.join('$TMPDIR_EXPORT', exported)
        dst = os.path.join('$DEVICE_DIR', scenario + '.png')
        if os.path.exists(src):
            shutil.move(src, dst)
            print(f'  {scenario}.png')
"
    fi

    rm -rf "$TMPDIR_EXPORT"
    rm -rf "$RESULT_BUNDLE"

    echo ""
  done

  # Clear status bar override
  if [[ -n "$SIM_UDID" ]]; then
    xcrun simctl status_bar "$SIM_UDID" clear
  fi
done

echo "=== Done ==="
echo "Screenshots at: $BASE_DIR/$VERSION/"
find "$BASE_DIR/$VERSION" -name "*.png" | sort
