#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASE_DIR="${1:-$REPO_ROOT/TalerPOS/build/screenshots}"

# Accept simulators as remaining args, or auto-detect
shift || true
if [[ $# -gt 0 ]]; then
  SIMULATORS=("$@")
else
  echo "Auto-detecting available simulators..."
  # Pick the latest-OS iPhone and iPad simulators
  SIMULATORS=()
  IPHONE=$(xcodebuild -project "$REPO_ROOT/TalerPOS.xcodeproj" -scheme TalerPOS -showdestinations 2>/dev/null \
    | grep 'platform:iOS Simulator' | grep 'name:iPhone' \
    | sed 's/.*name:\([^,}]*\).*/\1/' | sed 's/ *$//' | sort -u | tail -1)
  IPAD=$(xcodebuild -project "$REPO_ROOT/TalerPOS.xcodeproj" -scheme TalerPOS -showdestinations 2>/dev/null \
    | grep 'platform:iOS Simulator' | grep 'name:iPad' \
    | sed 's/.*name:\([^,}]*\).*/\1/' | sed 's/ *$//' | sort -u | tail -1)
  [[ -n "$IPHONE" ]] && SIMULATORS+=("$IPHONE")
  [[ -n "$IPAD" ]] && SIMULATORS+=("$IPAD")

  if [[ ${#SIMULATORS[@]} -eq 0 ]]; then
    echo "No simulators found. Pass device names manually." >&2
    exit 1
  fi
  echo "  Found: ${SIMULATORS[*]}"
  echo ""
fi

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

echo "=== Capturing screenshots for version $VERSION ==="
echo ""

for SIMULATOR in "${SIMULATORS[@]}"; do
  echo "--- Device: $SIMULATOR ---"

  # Sanitize device name for folder (spaces -> underscores, lowercase)
  DEVICE_FOLDER=$(echo "$SIMULATOR" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
  DEVICE_DIR="$BASE_DIR/$VERSION/$DEVICE_FOLDER"
  mkdir -p "$DEVICE_DIR"

  RESULT_BUNDLE="$DEVICE_DIR/ScreenshotTests.xcresult"
  rm -rf "$RESULT_BUNDLE"

  TMPDIR_EXPORT=$(mktemp -d)

  xcodebuild test \
    -project "$REPO_ROOT/TalerPOS.xcodeproj" \
    -scheme TalerPOS \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -only-testing:TalerPOSUITests/ScreenshotTests \
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

echo "=== Done ==="
echo "Screenshots at: $BASE_DIR/$VERSION/"
find "$BASE_DIR/$VERSION" -name "*.png" | sort
