#!/bin/bash
set -euo pipefail

# Keep compiler caches, temporary files, executables, and test bundle metadata
# inside this project. This validation does not launch Xcode or a simulator.
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
build_dir="$task_root/.build/validation"
mkdir -p "$build_dir/tmp" "$build_dir/mac-module-cache" "$build_dir/ios-module-cache" "$build_dir/persistence"
export TMPDIR="$build_dir/tmp/"
export WEATHERAPP_TEST_STORE_DIRECTORY="$build_dir/persistence"

# The location purpose string is a build setting, so project.yml must carry it and the checked-in project
# must have been regenerated from it; otherwise the next regeneration silently drops the prompt text.
for file in project.yml WeatherApp.xcodeproj/project.pbxproj; do
    grep -q 'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription' "$file" || {
        echo "$file is missing INFOPLIST_KEY_NSLocationWhenInUseUsageDescription (edit project.yml, then run scripts/generate-project.sh)" >&2
        exit 1
    }
done

developer_dir="$(xcode-select -p)"
compiler="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
mac_sdk="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
ios_sdk="$developer_dir/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
test_frameworks="$developer_dir/Platforms/MacOSX.platform/Developer/Library/Frameworks"

test_libraries="$developer_dir/Platforms/MacOSX.platform/Developer/usr/lib"
test_bundle="$build_dir/HKOTests.xctest"
mkdir -p "$test_bundle/Contents/MacOS"
python3 - <<'PYTHON'
import plistlib
from pathlib import Path
info = {"CFBundleExecutable": "HKOTests", "CFBundleIdentifier": "jc.WeatherApp.HKOValidation",
        "CFBundleName": "HKOTests", "CFBundlePackageType": "BNDL", "CFBundleDevelopmentRegion": "en",
        "CFBundleLocalizations": ["en", "zh-Hant"]}
Path(".build/validation/HKOTests.xctest/Contents/Info.plist").write_bytes(plistlib.dumps(info))
for language in ("en", "zh-Hant"):
    for table in ("Localizable", "InfoPlist"):
        destination = Path(f".build/validation/HKOTests.xctest/Contents/Resources/{language}.lproj/{table}.strings")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(Path(f"WeatherApp/Localization/{language}.lproj/{table}.strings").read_bytes())
PYTHON

"$compiler" -emit-library -enable-testing -swift-version 5 -D HKO_STANDALONE_TESTS \
    -target "$(uname -m)-apple-macos14.0" \
    -sdk "$mac_sdk" -module-cache-path "$build_dir/mac-module-cache" \
    -I "$test_libraries" -L "$test_libraries" -F "$test_frameworks" -framework XCTest \
    -Xlinker -rpath -Xlinker "$test_frameworks" \
    -Xlinker -rpath -Xlinker "$test_libraries" \
    WeatherApp/Model/WeatherModel.swift \
    WeatherApp/Model/AppSettings.swift \
    WeatherApp/Model/FavoriteStation.swift \
    WeatherApp/Model/RegionalWeatherExplorer.swift \
    WeatherApp/Model/WeatherWarningSnapshot.swift \
    WeatherApp/Model/HourlyRainfall.swift \
    WeatherApp/Model/RainfallMap.swift \
    WeatherApp/Model/SolarTimes.swift \
    WeatherApp/Model/NineDayForecastChart.swift \
    WeatherApp/Model/NearbyWeather.swift \
    WeatherApp/Model/HKOOpenDataTable.swift \
    WeatherApp/Model/MoonTimes.swift \
    WeatherApp/Model/TideTimes.swift \
    WeatherApp/Manager/LocationManager.swift \
    WeatherApp/Service/WeatherService.swift \
    WeatherApp/Service/WeatherRequestCoordinator.swift \
    WeatherApp/Service/FavoriteStationStore.swift \
    WeatherApp/ViewModel/WeatherViewModel.swift \
    WeatherApp/ViewModel/WeatherDashboardViewModel.swift \
    WeatherApp/ViewModel/HourlyRainfallViewModel.swift \
    WeatherApp/ViewModel/SolarTimesViewModel.swift \
    WeatherApp/ViewModel/MoonTidesViewModel.swift \
    WeatherApp/StaticFile/Static.swift \
    WeatherApp/StaticFile/RainfallStationCatalog.swift \
    WeatherApp/StaticFile/TideStationCatalog.swift \
    WeatherApp/Utils.swift \
    WeatherAppTests/WeatherAppTests.swift \
    WeatherAppTests/FavoriteStationTests.swift \
    WeatherAppTests/AppSettingsTests.swift \
    WeatherAppTests/RegionalWeatherExplorerTests.swift \
    WeatherAppTests/WeatherWarningSnapshotTests.swift \
    WeatherAppTests/HourlyRainfallTests.swift \
    WeatherAppTests/RainfallMapTests.swift \
    WeatherAppTests/SolarTimesTests.swift \
    WeatherAppTests/NineDayForecastChartTests.swift \
    WeatherAppTests/NearbyWeatherTests.swift \
    WeatherAppTests/MoonTidesTests.swift \
    -o "$test_bundle/Contents/MacOS/HKOTests"
"$developer_dir/Platforms/MacOSX.platform/Developer/Library/Xcode/Agents/xctest" "$test_bundle"

sources=()
while IFS= read -r source; do
    sources+=("$source")
done < <(find WeatherApp -name '*.swift' | sort)
"$compiler" -typecheck -swift-version 5 \
    -sdk "$ios_sdk" -target arm64-apple-ios17.6 \
    -module-cache-path "$build_dir/ios-module-cache" "${sources[@]}"
printf 'All HKO tests and iOS source type checks passed.\n'
